# vklimovs' Portage overlay

Personal Gentoo overlay: network monitoring and security tooling, directory
services, backup infrastructure, and the libraries those pull in. Everything
here is missing from ::gentoo or carries local patches. EAPI 8 throughout,
one profile, one maintainer.

## Using it

```sh
eselect repository add vklimovs git https://github.com/vklimovs/portage-overlay.git
emaint sync -r vklimovs
```

Packages are keyworded `~amd64` (some also `~x86` or `~arm64`), so most need
an entry in `/etc/portage/package.accept_keywords`.

## How this overlay differs from ::gentoo

Ebuilds follow the [devmanual](https://devmanual.gentoo.org/) and the
[QA policy guide](https://projects.gentoo.org/qa/policy-guide/). Only the
departures are recorded here: where the overlay tightens a rule, and where a
rule written for a multi-arch, multi-maintainer tree is met differently by a
single-profile personal overlay.

**Stricter.** Vendored third-party code is unbundled as policy rather than
per-package judgment, with no `system-*` / `bundled-libs` USE flags, and
`src_prepare` deletes every vendored tree not on an explicit allowlist — a
bump that vendors something new fails the build instead of compiling
silently. [UNBUNDLING.md](UNBUNDLING.md) is the policy; `net-analyzer/zeek`
is the reference implementation.

**Adapted to local conditions.**

- *Keywords, not stabilization.* Packages ship `~arch` and stay there — no
  arch team, no stabilization workflow — so `PotentialStable` is off.
  `dev-perl/BackupPC-XS` is the one exception, added stable in 2016 and left
  that way.
- *One profile is the QA target.* `amd64/23.0/desktop/plasma/hardened` is the
  only profile configured and the only one anything is built against, so
  findings from elsewhere belong upstream: `NonsolvableDepsInDev` is off
  because the zeek/nodejs failure it reports lives in the `amd64/23.0/x32`
  dev profile, and the fix belongs in Gentoo's x32 `package.use.mask`.
- *`package.mask` blocks carry rationale, not attribution.* Each block is its
  reason and the atom; with one maintainer, git holds the rest.
- *Thin manifests.* `Manifest` files list distfiles and nothing else; none
  carries an `EBUILD`, `AUX`, or `MISC` line. Refresh with
  `ebuild <cat>/<pn>/<pn>-<ver>.ebuild manifest` when distfiles change.

## Maintenance standard

- **Evidence, not assertion.** `<dev-libs/reproc-14.2.5` exists because
  14.2.5 made `reproc::event::source::process` by-value and broke Spicy — not
  because a bundled copy happened to be older. Fork distance is read off
  `ahead_by`: zeek's rapidjson and libkqueue "forks" measure zero and are
  treated as vanilla snapshots. Patch naming was settled by counting the live
  tree — 13,876 patches, 86.8% carrying a version.
- **Mechanism, not intention.** zeek's `keep_bundled` allowlist deletes every
  unlisted tree under `auxil/` and `3rdparty/` *and* dies on entries that
  matched nothing, so a newly vendored dep fails loudly and a stale exception
  cannot rot in place. The allowlist doubles as the package's bundled-code
  inventory for CVE triage.
- **Diagnose, don't dismiss.** pkgcheck findings get traced to a cause.
  `UnusedInherits: bash-completion-r1` was real: that eclass is now a shim
  whose entire body is `inherit shell-completion`, so ebuilds here inherit
  `shell-completion` directly.
- **Verify, don't reason.** Build tests run under real `FEATURES="sandbox
  network-sandbox"` — an unsandboxed `ebuild` run once passed llama-cpp that
  `emerge` then failed on a build-time npm/HuggingFace fetch. An edited patch
  is re-dry-run against the pinned tarball, however cosmetic the edit.
- **Write it where it's enforced.** UNBUNDLING.md exists because the same
  calls were re-litigated at every bump; the exceptions themselves live as
  `keep_bundled` entries in the ebuild, not in a document that can drift away
  from the build.
- **Terse artifacts.** No explanatory comments in ebuilds, subject-only
  commits, docs that link upstream rules instead of restating them. The
  vendor-tarball recipes are the one comment exception — instructional, not
  explanatory.
- **Correct over conventional.** CAF is packaged as the fork zeek actually
  uses, pinned, rather than bundled or force-fit onto upstream CAF; the
  copyright header matches the live `header.txt` rather than `skel.ebuild`.

## Conventions

| | |
| --- | --- |
| Copyright header | Exact copy of the live `header.txt` — `# Copyright <current year> Gentoo Authors`, not `skel.ebuild`'s `1999-YYYY` range. |
| Comments | None in ebuilds unless a reader could not infer the constraint (a CVE ID, an upstream issue gating a workaround). |
| `SLOT` | Literal: `SLOT="0/0.18.5"`, never `0/$(ver_cut 1-3)`. Package-manager metadata is written out, not computed. |
| Version bounds | Only from a demonstrated failure or a documented upstream minimum; the bound *is* the record of that evidence. Never derived from whatever version upstream vendors. |
| Patches | `${P}-description.patch`, the version being the one the patch was written against. On a bump, keep the old name unless the patch was actually regenerated. |
| Keywords | `~amd64` by default; `KEYWORDS=""` for live and pinned-commit VCS ebuilds, which is also how they avoid `VisibleVcsPkg`. |
| Snapshots | Real PVs — `_p<YYYYMMDD>` at a pinned commit, `_pre<n>` for upstream build numbers. Not `-9999`. |
| `metadata.xml` | vklimovs as sole maintainer, and an `<upstream><remote-id>` on everything with an upstream release axis (all but `acct-*` and `sec-keys/openpgp-keys-elastic`) — that is what `check_versions.py` walks. |
| Build-time network | Never. Disable the feature first (`-DLLAMA_BUILD_UI=OFF`) and reach for a vendor tarball only if it is load-bearing. |

### Vendor tarballs

Source material upstream doesn't ship in a release tarball comes from this
overlay's own GitHub releases, one sidecar per version: Go module trees for
the `go-module` eclass (zrepl, filebeat), composer trees (composer, librenms,
phpldapadmin), and zeek's unbundling patch series.

```
https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
```

The commands that produced each tarball sit in a comment block above
`SRC_URI`; `scripts/upload_vendor_tarballs.sh` finds them by the header line
ending in `generate the vendor tarball:`, re-runs them in a throwaway
directory, and uploads the result.

## Working on it

```sh
ebuild <pkg>.ebuild manifest       # refresh distfile digests
ebuild <pkg>.ebuild clean install  # phase loop while developing
emerge -1 <pkg>                    # real sandbox; the only build test that counts
eoldnew <pkg> && qa-cmp            # bumps: file-list and SONAME regressions
qa-vdb <pkg-version>               # RDEPEND vs DT_NEEDED; dlopen deps read as false misses
pkgcheck scan --commits            # changed packages only; bare `pkgcheck scan` for everything
pkgdev commit -s && pkgdev push --pull
```

`eoldnew`, `qa-cmp`, and `qa-vdb` come from `app-portage/iwdevtools`; the
first two want its bashrc hooks sourced from `/etc/portage/bashrc`.
`metadata/pkgcheck.conf` already turns on URL checks (`net`, `timeout = 30`)
and the two disables explained above, so `pkgcheck scan` needs no flags.

## Package notes

- **zeek** — most of the small C and C++ library packages in this overlay
  exist only as unbundling targets for it, and are maintained rather than
  warehoused; UNBUNDLING.md's appendix says which tree each one replaces.
  Two zeek lines are kept: 8.0.x and the current feature line, 8.2.x.
  Superseded feature lines are dropped rather than carried; 8.1 was never
  packaged. The unbundle series is regenerated in a scratch clone of upstream
  (`zeek-<ver>-pristine` tag, `unbundle-<ver>` branch) and shipped inside the
  vendor tarball — recipe in the ebuild header.
- **zeek-caf is not caf.** `dev-libs/zeek-caf` is zeek's own CAF fork at
  0.18.5, pinned to the commit Broker expects; `dev-libs/caf` is upstream CAF
  1.1.0. Same SONAME line, same install paths, so zeek-caf carries
  `RDEPEND="!dev-libs/caf"` and the two cannot coexist. Not consolidation
  candidates.
- **reproc** — `>=dev-libs/reproc-14.2.5` is masked: that release made
  `reproc::event::source::process` by-value and broke zeek's Spicy, which
  pins `<14.2.5`.
- **librenms** — the prebuilt composer vendor tarball is a decision, not
  laziness. ~125 production packages (Laravel 12, ~32 Symfony 7 components,
  against the three Symfony 3.4 components ::gentoo ships), and upstream is
  composer-coupled: `LibreNMS/Validations/Dependencies.php` shells out to
  `composer install --dry-run` and reports drift as a failure, and Laravel
  auto-discovery reads `vendor/composer/installed.json`. Debian has no
  package; the one Fedora COPR effort bundles the same prebuilt vendor dir.
  Code stays at `/opt/librenms` because upstream hard-codes that path in its
  cron, systemd, and logrotate files; writable state moves to
  `/var/{lib,cache,log}/librenms` and `/etc/librenms`, bridged by relative
  in-tree symlinks.
- **kibana-bin, filebeat** — held at the elasticsearch version ::gentoo
  ships, with newer ebuilds masked so they don't shadow the pin.
- **nsjail** — built against `dev-libs/kafel` (packaged here) instead of its
  bundled copy.
- **llama-cpp** — `-DLLAMA_BUILD_UI=OFF`: the web UI build chain fetches from
  npm and HuggingFace, which `network-sandbox` rightly blocks.

## Scripts

### `scripts/check_versions.py`

Compares the highest non-live ebuild version against the latest upstream
release from each `metadata.xml`'s `<remote-id>`. GitHub, PyPI, and Codeberg
are probed; `sourceforge` and `cpe` entries are ignored; packages with no
remote-id are skipped. Snapshot ebuilds are handled by diffing their pinned
commit against upstream HEAD instead of comparing versions.

```sh
python scripts/check_versions.py
python scripts/check_versions.py --no-pass   # skip pass(1) token lookup
```

The GitHub token comes from `$GITHUB_TOKEN`, then
`pass show Github/portage-overlay-releases`, otherwise unauthenticated
requests (60 req/hr).

### `scripts/upload_vendor_tarballs.sh`

Rebuilds vendor tarballs from the recipes embedded in the ebuilds and uploads
them to GitHub releases.

```sh
scripts/upload_vendor_tarballs.sh               # all packages
scripts/upload_vendor_tarballs.sh sys-fs/zrepl  # one package
scripts/upload_vendor_tarballs.sh --dry-run     # rehearse only
scripts/upload_vendor_tarballs.sh --force       # re-upload existing
```

## Maintainer

Vjaceslavs Klimovs &lt;vklimovs@gmail.com&gt;
