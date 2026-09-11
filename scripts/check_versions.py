#!/usr/bin/env python3
"""Compare each package in this overlay against the latest release its
``<remote-id>`` upstream reports.

Discovery is driven by portage itself: the overlay is handed to a private
``portdbapi`` at runtime, so it does not have to appear in ``repos.conf``.  Any
package whose ``metadata.xml`` carries a recognized ``<remote-id>`` (github,
pypi, codeberg) is probed, and no per-package configuration lives here.

Every version the overlay carries is listed, and a package counts as current
when any of them has caught up with upstream, so keeping an older line beside
the newest does not read as outdated.  Versions masked in
``profiles/package.mask`` are marked as masked.
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass
from functools import cmp_to_key
from pathlib import Path
from typing import Any

from portage.dbapi.porttree import portdbapi
from portage.package.ebuild.config import config
from portage.package.ebuild.getmaskingstatus import getmaskingstatus
from portage.repository.config import RepoConfig
from portage.versions import vercmp
from portage.xml.metadata import MetaDataXML

HTTP_TIMEOUT = 15
USER_AGENT = "portage-overlay-version-check/1.0"
PASS_ENTRY = "Github/portage-overlay-releases"
COMMIT_RE = re.compile(r"(?:archive/|COMMIT\s*=\s*[\"']?)([0-9a-f]{40})\b")
# Snapshot PVs (date or _pre build) cannot be compared to release tags, so for
# these a pinned commit is the right thing to diff.
SNAPSHOT_RE = re.compile(r"_pre|_p\d{6,}|^\d{8}")
COLOR = {"current": "32", "outdated": "33", "unknown": "35", "error": "31"}
# Unorderable version pairs compare equal instead of raising, so one junk tag
# cannot break a whole probe.
VKEY = cmp_to_key(lambda a, b: vercmp(a, b, silent=1) or 0)
# What a probe must survive: urllib raises OSError, json raises ValueError.
PROBE_ERRORS = (OSError, ValueError, RuntimeError)


@dataclass(frozen=True)
class Entry:
    """A package and every version this overlay carries."""

    cp: str
    pvs: tuple[str, ...]
    masked: frozenset[str]
    remotes: dict[str, str]
    commit: str | None


@dataclass(frozen=True)
class Result:
    """One probed package, ready to print."""

    entry: Entry
    status: str
    text: str


# --------------------------------------------------------------------------- #
# overlay discovery
# --------------------------------------------------------------------------- #

def open_overlay(overlay: Path) -> tuple[portdbapi, config, str]:
    """A portdbapi that sees the overlay without it being in repos.conf.

    ACCEPT_KEYWORDS is forced to ~amd64 because the overlay is ~arch only, and
    otherwise every package would read as keyword-masked and drown out the
    package.mask entries we actually want to surface."""
    # The repos.conf section name has to match repo-name in layout.conf.
    name = RepoConfig(None, {"location": str(overlay)}, local_config=False).name
    gentoo = config().repositories.mainRepoLocation()
    cfg = config(env={
        **os.environ,
        "ACCEPT_KEYWORDS": "~amd64",
        "PORTAGE_REPOSITORIES": (
            f"[DEFAULT]\nmain-repo = gentoo\n"
            f"[gentoo]\nlocation = {gentoo}\n"
            f"[{name}]\nlocation = {overlay}\nmasters = gentoo\n"),
    })
    location = next((r.location for r in cfg.repositories
                     if Path(r.location) == overlay), None)
    if location is None:
        sys.exit(f"error: portage did not accept {overlay} as a repository")
    return portdbapi(mysettings=cfg), cfg, location


def scan(overlay: Path) -> list[Entry]:
    """Every overlay package that declares a usable <remote-id>."""
    db, cfg, path = open_overlay(overlay)
    entries: list[Entry] = []
    for cp in sorted(db.cp_all(trees=[path])):
        remotes = remote_ids(Path(path) / cp / "metadata.xml")
        if not remotes:
            continue
        cpvs = db.cp_list(cp, mytree=path)
        # A live ebuild tracks HEAD, so it only stands in for a real version
        # when the package has none.
        carried = [c for c in cpvs if c.version != "9999"] or cpvs
        if not carried:
            continue
        newest = carried[-1]  # cp_list is ascending
        entries.append(Entry(
            cp=cp,
            pvs=tuple(c.version for c in carried),
            masked=frozenset(
                c.version for c in carried
                if "package.mask" in getmaskingstatus(c, settings=cfg, portdb=db)),
            remotes=remotes,
            commit=(commit_of(db.findname(newest))
                    if SNAPSHOT_RE.search(newest.version) else None)))
    return entries


def commit_of(ebuild: str | None) -> str | None:
    """The commit a snapshot ebuild pins, if it names one."""
    if ebuild is None:
        return None
    try:
        text = Path(ebuild).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    found = COMMIT_RE.search(text)
    return found.group(1) if found else None


def remote_ids(metadata_xml: Path) -> dict[str, str]:
    """First <remote-id> of each type, keyed by type."""
    try:
        upstreams = MetaDataXML(str(metadata_xml), None).upstream()
    except (OSError, SyntaxError):
        return {}
    out: dict[str, str] = {}
    for upstream in upstreams:
        for value, kind in upstream.remoteids:
            if kind and value:
                out.setdefault(kind, value)
    return out


# --------------------------------------------------------------------------- #
# upstream probes
# --------------------------------------------------------------------------- #

def http_json(url: str, token: str | None = None) -> Any:
    """Parsed JSON from an https URL."""
    if not url.startswith("https://"):
        raise ValueError(f"refusing non-https URL: {url}")
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    with urllib.request.urlopen(
            urllib.request.Request(url, headers=headers), timeout=HTTP_TIMEOUT) as resp:
        return json.load(resp)


def quote_repo(repo: str) -> str:
    """An owner/name pair, escaped for use in a URL path."""
    parts = repo.split("/", 1)
    if len(parts) != 2 or not all(parts):
        raise ValueError(f"bad repo spec: {repo!r}")
    return "/".join(urllib.parse.quote(p, safe="") for p in parts)


def github_tags(repo: str, token: str | None) -> list[str]:
    """Release tags if the repo publishes any, else plain tags."""
    # Prefer published releases, ranked by version rather than by whatever
    # upstream flagged "latest" -- some pin an older LTS line there.
    safe = quote_repo(repo)
    releases = http_json(f"https://api.github.com/repos/{safe}/releases?per_page=100", token)
    tags = [r.get("tag_name") for r in releases
            if not r.get("prerelease") and not r.get("draft")]
    if any(tags):
        return [t for t in tags if t]
    return [t.get("name") for t in
            http_json(f"https://api.github.com/repos/{safe}/tags?per_page=100", token)]


def pypi_tags(name: str, _token: str | None = None) -> list[str]:
    """The version PyPI reports as current."""
    data = http_json(f"https://pypi.org/pypi/{urllib.parse.quote(name, safe='')}/json")
    version = (data.get("info") or {}).get("version")
    return [version] if version else []


def codeberg_tags(repo: str, _token: str | None = None) -> list[str]:
    """The newest release tag, else the newest plain tag."""
    safe = quote_repo(repo)
    for url, key in ((f"https://codeberg.org/api/v1/repos/{safe}/releases?limit=1", "tag_name"),
                     (f"https://codeberg.org/api/v1/repos/{safe}/tags?limit=1", "name")):
        data = http_json(url)
        if data:
            return [data[0].get(key)]
    return []


# Probed in order, first remote-id present on a package wins.
PROBES: dict[str, Callable[[str, str | None], list[str]]] = {
    "github": github_tags, "pypi": pypi_tags, "codeberg": codeberg_tags}


def normalize(tag: str, pn: str) -> str:
    """Convert an upstream tag to the PV form the ebuilds use."""
    t = (tag or "").strip()
    if t.lower().startswith(f"{pn.lower()}-"):
        t = t[len(pn) + 1:]
    t = t.removeprefix("release-")
    found = re.match(r"[vV]\.?(\d.*)", t)
    return found.group(1) if found else t


def best_tag(pn: str, raw: list[str]) -> str | None:
    """Highest usable tag, in PV form.

    Candidates vercmp cannot order (rolling tags like "nightly") are dropped so
    they cannot shadow a real version by sorting first."""
    usable = [pv for pv in (normalize(t, pn) for t in raw)
              if pv and vercmp(pv, "0", silent=1) is not None]
    return max(usable, key=VKEY, default=None)


def github_commit_state(repo: str, commit: str, token: str | None) -> tuple[str, int]:
    """How a pinned commit compares to the default branch, and by how much."""
    safe = quote_repo(repo)
    info = http_json(f"https://api.github.com/repos/{safe}", token)
    branch = (info.get("default_branch") or "").strip()
    if not branch:
        raise RuntimeError("no default branch")
    head = urllib.parse.quote(branch, safe="")
    data = http_json(f"https://api.github.com/repos/{safe}/compare/{commit}...{head}", token)
    if not data.get("status"):
        raise RuntimeError("unexpected compare response")
    return data["status"], int(data.get("ahead_by") or 0)


def probe_commit(entry: Entry, token: str | None) -> Result:
    """Compare a snapshot ebuild's pinned commit against upstream HEAD."""
    try:
        state, ahead = github_commit_state(entry.remotes["github"], entry.commit or "", token)
    except PROBE_ERRORS as exc:
        return Result(entry, "error", f"ERROR (github: {exc})")
    if state == "ahead":
        return Result(entry, "outdated",
                      f"HEAD ({ahead} commit{'' if ahead == 1 else 's'} behind)")
    if state == "diverged":
        return Result(entry, "current", "HEAD (pinned)")
    if state in ("identical", "behind"):
        return Result(entry, "current", "HEAD (up to date)")
    return Result(entry, "unknown", f"HEAD ({state})")


def probe(entry: Entry, token: str | None) -> Result:
    """Compare one package against the latest release upstream reports."""
    # Live ebuilds always track upstream HEAD, so there is nothing to compare.
    if entry.pvs == ("9999",):
        return Result(entry, "current", "9999")
    if entry.commit and entry.remotes.get("github"):
        return probe_commit(entry, token)

    error = "no usable remote-id"
    for kind, fetch in PROBES.items():
        if kind not in entry.remotes:
            continue
        try:
            found = best_tag(entry.cp.split("/")[1], fetch(entry.remotes[kind], token))
        except PROBE_ERRORS as exc:
            error = f"{kind}: {exc}"
            continue
        if not found:
            error = f"{kind}: no releases or tags"
            continue
        # One carried version having caught up is enough, so an older line kept
        # on purpose does not drag the package to outdated.
        cmps = [vercmp(pv, found, silent=1) for pv in entry.pvs]
        if any(c is not None and c >= 0 for c in cmps):
            return Result(entry, "current", found)
        if all(c is None for c in cmps):
            return Result(entry, "unknown", found)
        return Result(entry, "outdated", f"{found}  <-- outdated")
    return Result(entry, "error", f"ERROR ({error})")


def token_from_pass() -> str | None:
    """First line of `pass show $PASS_ENTRY`, or None on any failure (pass not
    installed, entry missing, GPG agent locked).  Never raises, because the
    script must stay usable without a token."""
    try:
        with open("/dev/tty", encoding="utf-8") as tty:
            print("About to run `pass show` -- a pinentry prompt may appear. "
                  "Press Enter when ready: ", end="", file=sys.stderr, flush=True)
            tty.readline()
    except OSError:
        pass
    try:
        proc = subprocess.run(["pass", "show", PASS_ENTRY],
                              capture_output=True, text=True, timeout=10, check=True)
    except (FileNotFoundError, subprocess.TimeoutExpired, subprocess.CalledProcessError):
        return None
    return (proc.stdout.splitlines() or [""])[0].strip() or None


# --------------------------------------------------------------------------- #
# output
# --------------------------------------------------------------------------- #

def render(results: list[Result], use_color: bool) -> tuple[int, int]:
    """Print the table, and return the (outdated, error) counts."""
    def carried(r: Result) -> str:
        return " ".join(f"{pv} (masked)" if pv in r.entry.masked else pv
                        for pv in r.entry.pvs)

    name_w = max((len(r.entry.cp) for r in results), default=8)
    cur_w = max((len(carried(r)) for r in results), default=8)
    print(f"{'Package':<{name_w}} | {'Current':<{cur_w}} | Upstream")
    print("-" * (name_w + cur_w + 20))
    for r in results:
        text = f"\x1b[{COLOR[r.status]}m{r.text}\x1b[0m" if use_color else r.text
        print(f"{r.entry.cp:<{name_w}} | {carried(r):<{cur_w}} | {text}")
    return (sum(r.status == "outdated" for r in results),
            sum(r.status == "error" for r in results))


def main(argv: list[str] | None = None) -> int:
    """Scan the overlay, probe upstreams, print the table."""
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--overlay", type=Path, default=Path(__file__).resolve().parent.parent,
                    help="overlay root (default: %(default)s)")
    ap.add_argument("--workers", type=int, default=8,
                    help="parallel upstream probes (default: %(default)s)")
    ap.add_argument("--token", default=None,
                    help=f"GitHub API token (default: $GITHUB_TOKEN, else "
                         f"`pass show {PASS_ENTRY}`)")
    ap.add_argument("--no-pass", action="store_true",
                    help="do not consult pass(1) for the token")
    ap.add_argument("--no-color", action="store_true", help="disable ANSI color output")
    args = ap.parse_args(argv)

    overlay: Path = args.overlay.resolve()
    if not (overlay / "profiles").is_dir():
        print(f"error: {overlay} does not look like a Gentoo overlay (no profiles/)",
              file=sys.stderr)
        return 2

    entries = scan(overlay)
    if not entries:
        print("no packages with <remote-id> metadata found", file=sys.stderr)
        return 2

    token = args.token or os.environ.get("GITHUB_TOKEN")
    if not token and not args.no_pass:
        token = token_from_pass()
    if not token:
        print("note: no GitHub token available, rate limit is 60 req/hr", file=sys.stderr)

    with cf.ThreadPoolExecutor(max_workers=max(1, min(args.workers, len(entries)))) as ex:
        results = sorted(ex.map(lambda e: probe(e, token), entries),
                         key=lambda r: r.entry.cp)

    use_color = (sys.stdout.isatty() and not args.no_color
                 and os.environ.get("NO_COLOR") is None)
    outdated, errors = render(results, use_color)
    print(f"\n{len(results)} packages, {outdated} outdated, {errors} errors")
    return 1 if outdated or errors else 0


if __name__ == "__main__":
    sys.exit(main())
