# vklimovs' Portage overlay

Personal Gentoo overlay focused on network monitoring and security tooling,
directory services, and backup infrastructure. Contains packages not in the
main tree or carrying local patches.

## Adding the overlay

```sh
eselect repository add vklimovs git https://github.com/vklimovs/portage-overlay.git
emaint sync -r vklimovs
```

## Repository conventions

A few overlay-specific things that aren't in the Gentoo Development Manual.

### Manifests

`thin-manifests = true` (`metadata/layout.conf`), so the `Manifest` only lists
distfiles, not `files/` contents. Regenerate it after changing an ebuild or its
distfiles:

```sh
ebuild <cat>/<pn>/<pn>-<ver>.ebuild manifest
```

### QA (pkgcheck)

`pkgcheck` is preconfigured in `metadata/pkgcheck.conf`:

- `PotentialStable` is off, since nothing here ever gets stabilised.
- `NonsolvableDepsInDev` is off. zeek/nodejs can't be resolved in the
  `amd64/23.0/x32` dev profile, and the fix needs to go into Gentoo's x32
  `package.use.mask` rather than an overlay.
- Network URL checks are on (`net`, `timeout = 30`).

```sh
pkgcheck scan --commits   # only changed packages, fastest while developing
pkgcheck scan --net       # full scan including network URL checks
```

### Unbundling

Vendored third-party code gets unbundled per [UNBUNDLING.md](UNBUNDLING.md):
every vendored tree is classified with evidence, replaced by a system package
or enumerated as an exception, and swept fail-closed in `src_prepare` so a
bump that vendors something new breaks the build instead of compiling
silently. `net-analyzer/zeek` is the reference implementation.

### Vendor tarballs

Packages that need pre-assembled source material pull a sidecar tarball from
this overlay's GitHub releases: Go module trees for the `go-module` eclass
(zrepl, filebeat), PHP composer trees (composer, librenms, phpldapadmin), and
zeek's unbundling patch series.

```
https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
```

Those ebuilds carry a recipe comment block starting with
`# To (re)generate the vendor tarball:` that the upload script reads.

## Scripts

### `scripts/check_versions.py`

Compares the highest non-live ebuild version against the latest upstream
release, using the `<remote-id>` entries in each `metadata.xml`. Works with
GitHub, PyPI, and Codeberg.

```sh
python scripts/check_versions.py
python scripts/check_versions.py --no-pass   # skip pass(1) token lookup
```

The GitHub token comes from `$GITHUB_TOKEN`, then from
`pass show Github/portage-overlay-releases`, otherwise it falls back to
unauthenticated requests (60 req/hr).

### `scripts/upload_vendor_tarballs.sh`

Builds and uploads vendor tarballs to GitHub releases, reading the recipe
comment blocks embedded in the ebuilds.

```sh
scripts/upload_vendor_tarballs.sh               # all packages
scripts/upload_vendor_tarballs.sh sys-fs/zrepl  # one package
scripts/upload_vendor_tarballs.sh --dry-run     # rehearse only
scripts/upload_vendor_tarballs.sh --force       # re-upload existing
```

## Maintainer

Vjaceslavs Klimovs &lt;vklimovs@gmail.com&gt;
