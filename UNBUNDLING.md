# Unbundling policy

Normative policy for vendored third-party code in this overlay's packages.
The key words MUST, MUST NOT, SHOULD, and MAY are as in RFC 2119.
`net-analyzer/zeek` is the reference implementation.

## 1. Position relative to Gentoo policy

Gentoo's baseline is that bundling — shipping a private copy of a library,
statically linking one, or "including and (unconditionally) using snippets of
code copied from a library" — is harmful: security fixes lag behind the system
copy, disk and memory are duplicated, symbols collide, and downstream time is
spent on provenance archaeology ([Why not bundle
dependencies](https://wiki.gentoo.org/wiki/Why_not_bundle_dependencies)).

::gentoo tempers that baseline with per-package judgment and `system-*` /
`bundled-libs` USE flags because the tree serves every arch, profile, and
maintainer-bandwidth reality. None of those constraints exist here: one profile
(`amd64/23.0/desktop/plasma/hardened`), one maintainer, no stabilization
workflow. This overlay is therefore strictly harder than ::gentoo:

- Bundling is never the default. Every retained vendored tree is an
  enumerated, justified exception at the enforcement point (§5.2).
- Conditional bundling (`system-*` flags) is not used: it doubles the test
  matrix and leaves the bundled path as the effective default.

Binding upstream rules this policy incorporates rather than restates:

- [PG0011](https://projects.gentoo.org/qa/policy-guide/dependencies.html) —
  dependencies matching a range spanning (sub)slots carry explicit slot
  operators.
- [PG0704](https://projects.gentoo.org/qa/policy-guide/other-metadata.html) —
  `LICENSE` lists the licenses of all code combined with installed files,
  including retained bundled code.
- [PG0003](https://projects.gentoo.org/qa/policy-guide/dependencies.html) —
  revision bump when runtime dependencies change on a shipped version.
- [devmanual, Patches](https://devmanual.gentoo.org/ebuild-writing/misc-files/patches/index.html)
  — small patches in `files/`; large or numerous series ship as a distfile.

## 2. Principles

- **P1 — One copy per system.** Each third-party component exists on the
  system exactly once, so a security fix is applied once and reaches consumers
  by subslot rebuild, never by auditing vendored copies.
- **P2 — Policy is mechanism.** A rule enforced by review dies on the first
  version bump; a rule enforced by the build cannot drift. Verdicts are
  encoded where the build reads them (§5.2), not in prose.
- **P3 — The library test.** Judge a vendored tree by what it is, not where
  it sits. Something with its own identity, releases, and a replaceable
  interface boundary is a *library*: it gets unbundled or packaged. Something
  that exists only as part of the consumer — source snippets, internal
  runtimes — is the *consumer's source*: it stays, enumerated.
- **P4 — Evidence before verdict.** Provenance, divergence, consumption, and
  availability are measured (§4), never assumed.
- **P5 — Unbundled means exercised.** The work is done when the consumer's
  own test suite passes against the system copies, not when it links.

## 3. Scope

In scope, recursively: every child of a vendored-code container (`3rdparty/`,
`auxil/`, `vendor/`, `third_party/`, `external/`), every submodule, and every
copied source snippet — including bundles nested inside other bundles (Spicy's
`3rdparty/` inside zeek's `auxil/`).

Out of scope:

- **First-party subprojects** — same upstream, released with the consumer
  (zeek's broker, spicy, zeekctl, …). They *are* the package: exempt from
  unbundling, but MUST still be enumerated (§5.2), and their own vendored
  trees are in scope.
- **Language-ecosystem lockfile vendoring** (Go modules, cargo, composer) —
  governed by the existing vendor-tarball convention (README): those
  ecosystems pin and statically link by design and Gentoo packages them
  accordingly.

## 4. Classification

Evidence required per tree, before any verdict:

- **E1 Provenance** — upstream identity and exact vendored commit
  (`.gitmodules`, submodule pin, imported-from header).
- **E2 Divergence** — fork distance measured against the nearest upstream
  release (compare `ahead_by`/`behind_by`), not anyone's claim.
  `ahead_by == 0` is a vanilla snapshot, not a fork.
- **E3 Consumption** — whether and when the tree is built: linked into
  installed artifacts, build-tool only, test only, dead or foreign-platform;
  under which USE flags.
- **E4 Availability** — packaged in ::gentoo at a satisfying version,
  packaged here, or unpackaged.

| Class | Definition | Verdict |
|-------|------------|---------|
| A | Pristine upstream copy, packaged in ::gentoo | MUST unbundle; depend per §5.3 |
| B | Pristine upstream copy, not packaged anywhere | MUST unbundle; create the package here — release version if upstream releases, else `_p` snapshot at the vendored commit or a verified same-line descendant (0 behind) |
| C-lib | Genuine fork (E2 > 0, changes consumed) that passes the library test | MUST NOT stay silently bundled; package the fork itself as `${consumer}-${lib}`, pinned snapshot of the vendored commit |
| C-src | Genuine fork that fails the library test (internal runtime, churns with the consumer) | Keep bundled; enumerate with reason |
| D | Source snippets: single files or headers with no release process | Keep bundled; enumerate with reason; licenses counted per PG0704 |
| E | Not consumed on this profile: unbuilt tests/benchmarks, docs, foreign-platform code, disabled features | Delete in `src_prepare`; MUST NOT back a dependency |

Rulings:

- Upstream declaring external copies unsupported does not justify C-src. The
  supported configuration is *that exact code*; honor it by pinning the fork
  exactly as a C-lib package (`dev-libs/zeek-caf`), not by bundling.
- A vendor fork at `ahead_by == 0` is class A or B (zeek's rapidjson,
  libkqueue).
- Class B and C-lib packages are first-class overlay packages: proper
  category, literal `SLOT`, `~amd64`, own `metadata.xml` — maintained, not
  warehoused.
- Test-only trees built under a test USE flag (btest suites, doctest) are
  class A with test-conditional consumption, not class E.

## 5. Mechanism

### 5.1 The unbundle series

The transformation from pristine release to unbundled tree is a rebasable git
branch pair in a scratch clone of upstream: tag `<pkg>-<version>-pristine`,
branch `unbundle-<version>`. It ships as a `format-patch` series inside the
`${P}-vendor.tar.xz` release asset (reproducible tar: `--sort=name
--mtime=@0 --owner=0 --group=0 --numeric-owner`), applied with `eapply`
before `PATCHES`. The regeneration recipe lives in the ebuild header;
`scripts/upload_vendor_tarballs.sh` builds and uploads it for every shipped
version.

Rationale: a series is reviewable and rebasable where `sed` surgery in
`src_prepare` is neither, and the devmanual puts large patch series in
distfiles, not `files/`.

### 5.2 Fail-closed enforcement

`src_prepare` holds the single source of truth: a `keep_bundled` allowlist of
first-party subprojects plus class C-src/D exceptions, each exception carrying
its reason on the entry. Every other tree inside an in-scope container is
deleted. Consequences, all intended:

- A bump that vendors something new fails the build until the tree is
  classified. Re-adjudication is forced, not remembered.
- Nothing outside the allowlist can compile silently; "is the bundled copy
  really unused" is answered structurally, by absence.
- The allowlist is the package's bundled-code inventory (its SBOM): CVE
  triage for retained third-party code greps one place.

The sweep SHOULD also fail on allowlist entries that matched nothing: stale
exceptions rot silently otherwise.

### 5.3 Dependency encoding

- Linked deps on (sub)slotted packages carry `:=` (PG0011); ABI propagation
  replaces the consistency bundling used to provide.
- Version bounds encode verified requirements only: a demonstrated build or
  test failure against the excluded versions, or an upstream-documented
  minimum. The vendored version says where to look for a requirement, never
  what to write — an unverified floor overstates knowledge exactly the way an
  unverified bundling claim does. The bound itself is the record
  (`<dev-libs/reproc-14.2.5`, `>=dev-libs/rapidjson-1.1.0_p20250205`).
- DEPEND/BDEPEND/RDEPEND follow measured consumption (E3): header-only and
  build-time-only deps (cppzmq, pybind11) are BDEPEND.
- `LICENSE` includes the licenses of every retained C-src/D tree that reaches
  installed files (PG0704).

## 6. Verification

Ordered gates; an unbundle failing any of them is not done.

- **V1** Build via `emerge` under real `FEATURES="sandbox network-sandbox"`,
  across meaningful USE combinations. Unsandboxed `ebuild` runs prove nothing
  about network access or bundled fallbacks.
- **V2** Structural absence (§5.2): deleted code cannot link; omissions fail
  at compile time and are then classified, not restored ad hoc.
- **V3** The consumer's own test suite runs against the system copies. Every
  baseline delta is classified: test-data artifact → baseline patch in
  `files/`; genuine behavioral difference → find the buggy side, patch and
  report it (zeek's from-json precision bug, exposed by system rapidjson);
  true incompatibility → that dep's verdict reverts to C, recorded.
- **V4** Linkage audit: `qa-vdb` (RDEPEND ↔ `DT_NEEDED`) after install;
  `qa-cmp` across bumps for file-list and SONAME regressions.
- **V5** Feature probes for what the suite doesn't reach (telemetry scrape,
  cluster backends, per-USE functionality).

## 7. Lifecycle

- Every version bump re-tags pristine and rebases the unbundle series. A
  rebase conflict means upstream touched vendored code: re-run §4 on that
  tree before resolving. New trees surface as §5.2 build failures; removed
  trees surface as dead allowlist entries and are pruned.
- Fork drift: E2 is re-measured for every C-class tree at each bump. Fork
  merged or released upstream → promote to A/B. Snapshot (`_p`) packages move
  to real versions when upstream releases.
- Bounds: at each bump, existing bounds are re-checked against the newly
  vendored versions; a bound whose motivating incompatibility is verified
  fixed is removed.
- Unbundling work that changes runtime deps of an already-shipped version is
  a revision bump (PG0003).
- Vendor tarballs exist for every shipped version with digests in the
  Manifest; a stale series fails `eapply` loudly, never silently.

## 8. Exceptions and amendment

There are no out-of-band exceptions. An exception exists if and only if it is
a `keep_bundled` entry with a reason, in the ebuild, where it is enforced.
Changing this policy is a change to this file, in the same commit series as
the ebuild change that motivates it.

## Appendix: zeek class assignments (8.0.9 / 8.2.1)

| Class | Trees |
|-------|-------|
| A | c-ares, expected-lite, rapidjson†, libkqueue†, sqlite, prometheus-cpp (+ civetweb), cppzmq, pybind11, nlohmann_json, libb64, utfcpp, doctest (btest-conditional) |
| B | highwayhash, IXWebSocket, out_ptr, reproc, utf8proc (dropped from ::gentoo), LightPcapNg (8.2+) |
| C-lib | CAF → `dev-libs/zeek-caf` |
| C-src | spicy fiber, justrx |
| D | patricia, ConvertUTF, in_cksum, bsd-getopt-long, modp_numtoa, setsignal, strsep, zeek_inet_ntop, jthread/stop_token, SafeInt, tinyformat, ArticleEnumClass-v2, pathfind, libaca (8.2+) |
| E | google-benchmark (`SPICY_ENABLE_BENCHMARKS=no`), libunistd, vcpkg glue |

† vendor forks at `ahead_by == 0`, treated as pristine snapshots.
