#!/usr/bin/env python3
"""Compare the highest non-live ebuild version of each package in this overlay
against the latest release reported by its ``<remote-id>`` upstream.

Discovery is driven entirely by the overlay tree: any ``metadata.xml`` with a
recognised ``<remote-id>`` (github, pypi, codeberg) is probed.  No per-package
configuration lives in this script.
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

from portage.versions import vercmp


HTTP_TIMEOUT = 15
USER_AGENT = "portage-overlay-version-check/1.0"
PASS_ENTRY = "Github/portage-overlay-releases"
SKIP_CATEGORIES = {"acct-group", "acct-user", "metadata", "profiles", "scripts",
                   "eclass", "licenses", "distfiles"}
PROBE_ORDER = ("github", "pypi", "codeberg")
EBUILD_RE = re.compile(r"^(?P<pn>.+)-(?P<pv>\d[^-]*(?:[._-][^-]+)*?)(?:-r\d+)?\.ebuild$")
COMMIT_RE = re.compile(r"(?:archive/|COMMIT\s*=\s*[\"']?)([0-9a-f]{40})\b")
# Snapshot PVs (date or _pre build) can't be compared to release tags, so
# these are the ones for which a pinned commit is the right thing to diff.
SNAPSHOT_RE = re.compile(r"_pre|_p\d{6,}|^\d{8}")


@dataclass(frozen=True)
class Package:
    cpn: str
    pn: str
    current: str | None
    remotes: dict[str, str]
    commit: str | None = None


@dataclass(frozen=True)
class Result:
    pkg: Package
    upstream: str | None
    error: str | None
    # GitHub compare status of a pinned commit against upstream HEAD.
    commit_state: str | None = None
    commit_behind: int | None = None

    @property
    def status(self) -> str:
        if self.error:
            return "error"
        if self.commit_state is not None:
            if self.commit_state == "identical":
                return "current"
            if self.commit_state == "ahead":
                return "outdated"
            if self.commit_state == "behind":
                return "ahead"
            return "unknown"
        if self.pkg.current is None or self.upstream is None:
            return "unknown"
        cmp = vercmp(self.pkg.current, self.upstream, silent=1)
        if cmp is None:
            return "unknown"
        if cmp < 0:
            return "outdated"
        if cmp > 0:
            return "ahead"
        return "current"


# --------------------------------------------------------------------------- #
# overlay discovery
# --------------------------------------------------------------------------- #

def discover_packages(overlay: Path) -> list[Package]:
    pkgs: list[Package] = []
    for cat in sorted(p for p in overlay.iterdir() if p.is_dir()):
        if cat.name.startswith(".") or cat.name in SKIP_CATEGORIES or "-" not in cat.name:
            continue
        for pkg_dir in sorted(p for p in cat.iterdir() if p.is_dir()):
            ebuilds = list(pkg_dir.glob("*.ebuild"))
            if not ebuilds:
                continue
            current, current_ebuild = pick_current(ebuilds)
            remotes = parse_remote_ids(pkg_dir / "metadata.xml")
            if not remotes:
                continue
            pkgs.append(Package(
                cpn=f"{cat.name}/{pkg_dir.name}",
                pn=pkg_dir.name,
                current=current,
                remotes=remotes,
                commit=(extract_commit(current_ebuild)
                        if current_ebuild and current and SNAPSHOT_RE.search(current)
                        else None),
            ))
    return pkgs


def pick_current(ebuilds: list[Path]) -> tuple[str | None, Path | None]:
    versions: list[tuple[str, Path]] = []
    live: Path | None = None
    for e in ebuilds:
        m = EBUILD_RE.match(e.name)
        if not m:
            continue
        pv = m.group("pv")
        if pv == "9999":
            live = e
            continue
        versions.append((pv, e))
    if not versions:
        return ("9999", live) if live else (None, None)
    best = versions[0]
    for v in versions[1:]:
        if (vercmp(v[0], best[0], silent=1) or 0) > 0:
            best = v
    return best


def extract_commit(ebuild: Path) -> str | None:
    try:
        text = ebuild.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    m = COMMIT_RE.search(text)
    return m.group(1) if m else None


def parse_remote_ids(metadata_xml: Path) -> dict[str, str]:
    if not metadata_xml.is_file():
        return {}
    try:
        root = ET.parse(metadata_xml).getroot()
    except ET.ParseError:
        return {}
    out: dict[str, str] = {}
    for r in root.iterfind("./upstream/remote-id"):
        kind = (r.get("type") or "").strip()
        value = (r.text or "").strip()
        if kind and value and kind not in out:
            out[kind] = value
    return out


# --------------------------------------------------------------------------- #
# upstream probes
# --------------------------------------------------------------------------- #

def http_json(url: str, headers: dict[str, str] | None = None) -> object:
    if not url.startswith("https://"):
        raise ValueError(f"refusing non-https URL: {url}")
    hdrs = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    if headers:
        hdrs.update(headers)
    req = urllib.request.Request(url, headers=hdrs)
    with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
        return json.load(resp)


def _quote_repo(repo: str) -> str:
    parts = repo.split("/", 1)
    if len(parts) != 2 or not all(parts):
        raise ValueError(f"bad repo spec: {repo!r}")
    return "/".join(urllib.parse.quote(p, safe="") for p in parts)


def latest_github(repo: str, token: str | None) -> str:
    safe = _quote_repo(repo)
    headers = {"Authorization": f"Bearer {token}"} if token else None
    try:
        data = http_json(f"https://api.github.com/repos/{safe}/releases/latest", headers)
        if isinstance(data, dict):
            tag = (data.get("tag_name") or "").strip()
            if tag:
                return tag
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
    data = http_json(f"https://api.github.com/repos/{safe}/tags?per_page=10", headers)
    if isinstance(data, list) and data:
        name = (data[0].get("name") or "").strip()
        if name:
            return name
    raise RuntimeError("no releases or tags")


def github_commit_state(repo: str, commit: str, token: str | None) -> tuple[str, int]:
    safe = _quote_repo(repo)
    headers = {"Authorization": f"Bearer {token}"} if token else None
    info = http_json(f"https://api.github.com/repos/{safe}", headers)
    branch = (info.get("default_branch") or "").strip() if isinstance(info, dict) else ""
    if not branch:
        raise RuntimeError("no default branch")
    head = urllib.parse.quote(branch, safe="")
    data = http_json(
        f"https://api.github.com/repos/{safe}/compare/{commit}...{head}", headers)
    if not isinstance(data, dict) or not data.get("status"):
        raise RuntimeError("unexpected compare response")
    return data["status"], int(data.get("ahead_by") or 0)


def latest_pypi(name: str) -> str:
    safe = urllib.parse.quote(name, safe="")
    data = http_json(f"https://pypi.org/pypi/{safe}/json")
    if not isinstance(data, dict):
        raise RuntimeError("unexpected response shape")
    version = (((data.get("info") or {}).get("version")) or "").strip()
    if not version:
        raise RuntimeError("no version in info")
    return version


def latest_codeberg(repo: str) -> str:
    safe = _quote_repo(repo)
    data = http_json(f"https://codeberg.org/api/v1/repos/{safe}/releases?limit=1")
    if isinstance(data, list) and data:
        tag = (data[0].get("tag_name") or "").strip()
        if tag:
            return tag
    data = http_json(f"https://codeberg.org/api/v1/repos/{safe}/tags?limit=1")
    if isinstance(data, list) and data:
        name = (data[0].get("name") or "").strip()
        if name:
            return name
    raise RuntimeError("no releases or tags")


# --------------------------------------------------------------------------- #
# normalisation + driver
# --------------------------------------------------------------------------- #

# Per-package upstream-tag rewrites. Hacky but local: when an upstream's
# tag scheme doesn't match Gentoo PV ordering, map it to the form used by
# the ebuild here so vercmp does the right thing.
TAG_REWRITES: tuple[tuple[str, re.Pattern[str], str], ...] = (
    # llama.cpp tags daily builds as bNNNN; ebuilds use 0_preNNNN.
    ("sci-misc/llama-cpp", re.compile(r"^b(\d+)$"), r"0_pre\1"),
)


def normalize_tag(tag: str, pkg: "Package") -> str:
    t = tag.strip()
    pn_prefix = f"{pkg.pn}-"
    if t.lower().startswith(pn_prefix.lower()):
        t = t[len(pn_prefix):]
    if t.startswith("release-"):
        t = t[len("release-"):]
    if len(t) > 1 and t[0] in "vV" and t[1].isdigit():
        t = t[1:]
    for cpn, pat, repl in TAG_REWRITES:
        if cpn == pkg.cpn:
            t = pat.sub(repl, t)
    return t


def token_from_pass() -> str | None:
    """Return the first line of `pass show $PASS_ENTRY`, or None on any failure
    (pass not installed, entry missing, GPG agent locked, etc.). Never raises;
    the script must remain usable without a token."""
    try:
        with open("/dev/tty") as tty:
            print("About to run `pass show` -- a pinentry prompt may appear. "
                  "Press Enter when ready: ", end="", file=sys.stderr, flush=True)
            tty.readline()
    except OSError:
        pass
    try:
        proc = subprocess.run(
            ["pass", "show", PASS_ENTRY],
            capture_output=True, text=True, timeout=10, check=True,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, subprocess.CalledProcessError):
        return None
    line = proc.stdout.splitlines()[0].strip() if proc.stdout else ""
    return line or None


def fetch_upstream(pkg: Package, token: str | None) -> Result:
    # Live-only ebuilds always track upstream HEAD; there is no meaningful
    # release to compare against, so just mirror "9999" and call it current.
    if pkg.current == "9999":
        return Result(pkg=pkg, upstream="9999", error=None)
    # Snapshot ebuilds pin a commit; comparing PV against the newest tag is
    # meaningless, so diff the pinned SHA against upstream HEAD instead.
    if pkg.commit and pkg.remotes.get("github"):
        try:
            state, behind = github_commit_state(
                pkg.remotes["github"], pkg.commit, token)
            return Result(pkg=pkg, upstream="HEAD", error=None,
                          commit_state=state, commit_behind=behind)
        except Exception as e:
            return Result(pkg=pkg, upstream=None, error=f"github: {e}")
    last_error: str | None = None
    for kind in PROBE_ORDER:
        rid = pkg.remotes.get(kind)
        if not rid:
            continue
        try:
            if kind == "github":
                raw = latest_github(rid, token)
            elif kind == "pypi":
                raw = latest_pypi(rid)
            elif kind == "codeberg":
                raw = latest_codeberg(rid)
            else:
                continue
            return Result(pkg=pkg, upstream=normalize_tag(raw, pkg), error=None)
        except Exception as e:
            last_error = f"{kind}: {e}"
    return Result(pkg=pkg, upstream=None, error=last_error or "no usable remote-id")


def render(results: list[Result], use_color: bool) -> tuple[int, int]:
    def paint(s: str, code: str) -> str:
        return f"\x1b[{code}m{s}\x1b[0m" if use_color else s

    name_w = max((len(r.pkg.cpn) for r in results), default=8)
    cur_w = max((len(r.pkg.current or "-") for r in results), default=8)

    header = f"{'Package':<{name_w}} | {'Current':<{cur_w}} | Upstream"
    print(header)
    print("-" * (name_w + cur_w + 20))

    outdated = errors = 0
    for r in results:
        cur = r.pkg.current or "-"
        status = r.status
        if r.commit_state is not None and status != "error":
            n = r.commit_behind or 0
            label = {
                "current": "HEAD (up to date)",
                "outdated": f"HEAD ({n} commit{'s' if n != 1 else ''} behind)",
                "ahead": "HEAD (local ahead)",
            }.get(status, f"HEAD ({r.commit_state})")
            color = {"current": "32", "outdated": "33", "ahead": "36"}.get(status, "35")
            outdated += status == "outdated"
            print(f"{r.pkg.cpn:<{name_w}} | {cur:<{cur_w}} | {paint(label, color)}")
            continue
        if status == "error":
            up = paint(f"ERROR ({r.error})", "31")
            errors += 1
        elif status == "outdated":
            up = paint(f"{r.upstream}  <-- outdated", "33")
            outdated += 1
        elif status == "ahead":
            up = paint(f"{r.upstream}  (local newer)", "36")
        elif status == "unknown":
            up = paint(r.upstream or "-", "35")
        else:
            up = paint(r.upstream or "-", "32")
        print(f"{r.pkg.cpn:<{name_w}} | {cur:<{cur_w}} | {up}")
    return outdated, errors


def main(argv: list[str] | None = None) -> int:
    default_overlay = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--overlay", type=Path, default=default_overlay,
                    help="overlay root (default: %(default)s)")
    ap.add_argument("--workers", type=int, default=8,
                    help="parallel upstream probes (default: %(default)s)")
    ap.add_argument("--token", default=None,
                    help=f"GitHub API token (default: $GITHUB_TOKEN, "
                         f"else `pass show {PASS_ENTRY}`)")
    ap.add_argument("--no-pass", action="store_true",
                    help="do not consult pass(1) for the token")
    ap.add_argument("--no-color", action="store_true", help="disable ANSI colour output")
    args = ap.parse_args(argv)

    overlay: Path = args.overlay.resolve()
    if not (overlay / "profiles").is_dir():
        print(f"error: {overlay} does not look like a Gentoo overlay (no profiles/)", file=sys.stderr)
        return 2

    pkgs = discover_packages(overlay)
    if not pkgs:
        print("no packages with <remote-id> metadata found", file=sys.stderr)
        return 2

    token = args.token or os.environ.get("GITHUB_TOKEN")
    if not token and not args.no_pass:
        token = token_from_pass()
    if not token:
        print("note: no GitHub token available; rate limit is 60 req/hr",
              file=sys.stderr)

    workers = max(1, min(args.workers, len(pkgs)))
    results: list[Result] = []
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        for r in ex.map(lambda p: fetch_upstream(p, token), pkgs):
            results.append(r)
    results.sort(key=lambda r: r.pkg.cpn)

    use_color = sys.stdout.isatty() and not args.no_color and os.environ.get("NO_COLOR") is None
    outdated, errors = render(results, use_color)

    print()
    print(f"{len(results)} packages, {outdated} outdated, {errors} errors")
    return 1 if outdated or errors else 0


if __name__ == "__main__":
    sys.exit(main())
