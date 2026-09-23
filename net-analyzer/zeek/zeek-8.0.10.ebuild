# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..15} )
VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/openpgp-keys/zeek.asc

inherit cmake multiprocessing python-single-r1 verify-sig

DESCRIPTION="The Zeek Network Security Monitor"
HOMEPAGE="https://zeek.org/"

# The vendor tarball carries the unbundling patch series (the vendored auxil/
# libraries replaced by system packages), format-patch'd from the zeek
# unbundling git project. Export ZEEK_UNBUNDLE_DIR to point at that project
# before regenerating. --full-index keeps the output independent of that
# project's object count, which otherwise decides how far git abbreviates the
# index lines and so changes the tarball's hash.
# To (re)generate the vendor tarball:
#   git -C "${ZEEK_UNBUNDLE_DIR:?}" format-patch --no-signature --full-index \
#       -o "${PWD}/unbundle" "zeek-${PV}-pristine".."unbundle-${PV}"
#   tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
#       -cf - unbundle | xz -9e >"${P}-vendor.tar.xz"
# Then upload as a release asset to vklimovs/portage-overlay.
if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/zeek/zeek"
else
	MY_P="${PN}-${PV/_/-}"
	MY_PV="${PV/_/-}"
	SRC_URI="https://github.com/zeek/zeek/releases/download/v${MY_PV}/${MY_P}.tar.gz
		https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
		verify-sig? ( https://github.com/zeek/zeek/releases/download/v${MY_PV}/${MY_P}.tar.gz.asc )"
	KEYWORDS="~amd64"
fi

LICENSE="BSD BSD-4 CC-BY-4.0 ISC UoI-NCSA
	spicy? ( BSD-2 Boost-1.0 LGPL-3 MIT )"
SLOT="0"
IUSE="+btest cron curl debug geoip2 ipsumdump jemalloc kerberos
	+python redis sendmail +spicy static-libs tcmalloc +tools +zeek-client
	+zeekctl +zkg +zeromq"

RDEPEND="
	dev-cpp/expected-lite
	dev-cpp/highwayhash:=
	dev-cpp/out_ptr
	dev-cpp/prometheus-cpp
	dev-db/sqlite:3=
	dev-libs/libkqueue:=
	dev-libs/openssl:0=
	>=dev-libs/rapidjson-1.1.0_p20250205
	dev-libs/zeek-caf:=
	net-dns/c-ares:=
	>=net-libs/IXWebSocket-12.0.1_p20260910:=
	net-libs/libpcap:=
	virtual/zlib:0=
	www-servers/civetweb[cxx]
	cron? ( virtual/cron )
	curl? ( net-misc/curl )
	geoip2? ( dev-libs/libmaxminddb:0= )
	ipsumdump? ( net-analyzer/ipsumdump )
	jemalloc? ( dev-libs/jemalloc:0= )
	kerberos? ( virtual/krb5 )
	python? ( ${PYTHON_DEPS} )
	redis? ( dev-libs/hiredis:= )
	sendmail? ( virtual/mta )
	spicy? (
		dev-cpp/nlohmann_json
		dev-libs/libb64:=
		<dev-libs/reproc-14.2.5:=
		dev-libs/utf8proc:=
		>=dev-libs/utfcpp-4
	)
	tcmalloc? ( dev-util/google-perftools:= )
	zeek-client? ( ${PYTHON_DEPS}
		$(python_gen_cond_dep '
			>=dev-python/websocket-client-1.8.0[${PYTHON_USEDEP}]
			>=dev-python/argcomplete-3.4.0[${PYTHON_USEDEP}]
		')
	)
	zeromq? ( net-libs/zeromq:= )
	zkg? ( ${PYTHON_DEPS}
		$(python_gen_cond_dep '
			>=dev-python/gitpython-3.1.43[${PYTHON_USEDEP}]
			>=dev-python/semantic-version-2.10.0[${PYTHON_USEDEP}]
		')
	)"

DEPEND="${RDEPEND}"

BDEPEND="dev-cpp/doctest
	>=sys-devel/bison-2.5
	virtual/pkgconfig
	python? ( ${PYTHON_DEPS}
		$(python_gen_cond_dep '>=dev-python/pybind11-2.6.1[${PYTHON_USEDEP}]')
	)
	zeekctl? ( >=dev-lang/swig-3.0 )
	zeromq? ( >=net-libs/cppzmq-4.9.0 )
	verify-sig? ( sec-keys/openpgp-keys-zeek )"

REQUIRED_USE="zeekctl? ( python )
	zeek-client? ( python )
	zkg? ( python )
	cron? ( zeekctl )
	?? ( jemalloc tcmalloc )
	python? ( ${PYTHON_REQUIRED_USE} )"

# The test suite needs the btest infrastructure, only built with USE=btest.
RESTRICT="!btest? ( test )"

PATCHES=(
	# Introduced for 8.0.9 and unchanged since; per Gentoo convention a patch keeps
	# the filename of the version that introduced it.
	"${FILESDIR}"/${PN}-8.0.9-do-not-strip-broker-binary.patch
	"${FILESDIR}"/${PN}-8.0.9-do-not-remove-broker-headers-at-install-time.patch
	"${FILESDIR}"/${PN}-8.0.9-do-not-create-run-dirs-at-install-time.patch
	"${FILESDIR}"/${PN}-8.0.9-do-not-remove-stale-scripts-at-install-time.patch
	# Make the btest suite pass against the system libraries. from-json is a
	# genuine round-trip bug exposed by system rapidjson; the rest adjust test
	# data, not behavior.
	"${FILESDIR}"/${PN}-8.0.9-from-json-full-precision.patch
	# The test hardcodes /tmp/zeek.trace; a root-owned copy left by an earlier
	# root-run suite fails it for the portage user.
	"${FILESDIR}"/${PN}-8.0.9-spicy-nested-test-no-tmp.patch
	# Tracks sqlite's float rendering (>=3.41 is shortest-round-trip); re-run
	# btest -U if it shifts again.
	"${FILESDIR}"/${PN}-8.0.9-sqlite-wikipedia-baseline.patch
	"${FILESDIR}"/${PN}-8.0.9-coverage-load-baseline-canonifier.patch
)

if [[ ! ${PV} == 9999 ]]; then
	S="${WORKDIR}/${MY_P}"
fi

src_unpack() {
	if [[ ${PV} == 9999 ]]; then
		git-r3_src_unpack
	else
		# Only upstream's tarball is signed; the vendor tarball is this overlay's own
		# release asset. verify-sig_src_unpack demands a signature for every distfile
		# and would die on that one.
		use verify-sig &&
			verify-sig_verify_detached "${DISTDIR}"/${MY_P}.tar.gz{,.asc}
		default
	fi
}

src_prepare() {
	# Replace the vendored auxil/ libraries with system packages. The series comes
	# from the vendor tarball (recipe above) and is applied before ${PATCHES} so
	# the test-suite fixes land on the unbundled tree. When rebasing it: system
	# utf8proc and b64 attach PUBLIC to the *-rt-objects OBJECT libs, never to
	# hilti-rt/spicy-rt -- those are raw ar archives with no link interface, and
	# consumers reach the objects through cmake/Util.cmake.
	eapply "${WORKDIR}"/unbundle

	if ! use static-libs; then
		sed -i 's:add_library(paraglob STATIC:add_library(paraglob SHARED:' \
			auxil/paraglob/src/CMakeLists.txt || die
	fi

	if [[ ${PV} == 9999 ]]; then
		sed -i "s/$/_$(git rev-parse --short HEAD)-gentoo/" VERSION || die
	fi

	# Unbundling is fail-closed: allowlist the trees that genuinely cannot be
	# replaced by a system package (each with the reason) plus Zeek's own auxil/
	# components, then hard-delete every other vendored tree under */3rdparty/ and
	# */auxil/. Anything the unbundle series redirects to a system package (see
	# RDEPEND) falls outside the allowlist and is removed here; a newly vendored
	# dependency on a bump also lands outside it and breaks the build loudly
	# instead of silently compiling a private copy.
	local -A keep_bundled=(
		# Zeek's own components, not third-party:
		[auxil/bifcl]=1
		[auxil/binpac]=1
		[auxil/broker]=1
		[auxil/btest]=1
		[auxil/gen-zam]=1
		[auxil/netcontrol-connectors]=1
		[auxil/package-manager]=1
		[auxil/paraglob]=1
		[auxil/spicy]=1
		[auxil/zeek-af_packet-plugin]=1
		[auxil/zeek-aux]=1
		[auxil/zeek-client]=1
		[auxil/zeekctl]=1
		[auxil/zeekjs]=1
		[auxil/zeekctl/auxil/capstats]=1
		[auxil/zeekctl/auxil/pysubnettree]=1
		[auxil/zeekctl/auxil/trace-summary]=1

		# Third-party kept bundled — no independently-packaged upstream:
		# fiber's amd64 asm switches context by raw jmp and manual rsp swap with no
		# .note.gnu.property and no endbr64, so the linker strips IBT/SHSTK from
		# zeek and every spicy-linked binary. Expected on the hardened profile;
		# restoring the note faults on the first fiber switch during parsing.
		[auxil/spicy/3rdparty/fiber]=1               # Spicy-internal, no released upstream
		[auxil/spicy/3rdparty/justrx]=1              # Spicy-internal, no released upstream
		[auxil/spicy/3rdparty/SafeInt]=1             # header-only, no Gentoo package
		[auxil/spicy/3rdparty/tinyformat]=1          # header-only, no Gentoo package
		[auxil/spicy/3rdparty/ArticleEnumClass-v2]=1 # header-only snippet, no upstream
		[auxil/spicy/3rdparty/pathfind]=1            # header-only (LGPL-3), no Gentoo package
		[auxil/broker/3rdparty/ConvertUTF.c]=1
		[auxil/broker/3rdparty/ConvertUTF.h]=1
		[auxil/broker/3rdparty/bsd-getopt-long.c]=1
		[auxil/broker/3rdparty/bsd-getopt-long.h]=1
		[auxil/broker/3rdparty/in_cksum.cc]=1
		[auxil/broker/3rdparty/modp_numtoa.c]=1
		[auxil/broker/3rdparty/modp_numtoa.h]=1
		[auxil/broker/3rdparty/patricia.c]=1
		[auxil/broker/3rdparty/patricia.h]=1
		[auxil/broker/3rdparty/setsignal.c]=1
		[auxil/broker/3rdparty/setsignal.h]=1
		[auxil/broker/3rdparty/strsep.c]=1
		[auxil/broker/3rdparty/zeek_inet_ntop.c]=1
		[auxil/broker/3rdparty/zeek_inet_ntop.h]=1
		[src/3rdparty/ConvertUTF.c]=1
		[src/3rdparty/ConvertUTF.h]=1
		[src/3rdparty/bsd-getopt-long.c]=1
		[src/3rdparty/bsd-getopt-long.h]=1
		[src/3rdparty/in_cksum.cc]=1
		[src/3rdparty/jthread.hpp]=1
		[src/3rdparty/stop_token.hpp]=1
		[src/3rdparty/modp_numtoa.c]=1
		[src/3rdparty/modp_numtoa.h]=1
		[src/3rdparty/patricia.c]=1
		[src/3rdparty/patricia.h]=1
		[src/3rdparty/setsignal.c]=1
		[src/3rdparty/setsignal.h]=1
		[src/3rdparty/strsep.c]=1
		[src/3rdparty/zeek_inet_ntop.c]=1
		[src/3rdparty/zeek_inet_ntop.h]=1

		# Build glue and the hilti include symlinks into the kept trees above:
		[src/3rdparty/.clang-format]=1
		[auxil/spicy/3rdparty/.clang-tidy]=1
		[auxil/spicy/3rdparty/CMakeLists.txt]=1
		[auxil/spicy/3rdparty/LICENSE.3rdparty]=1
		[auxil/spicy/3rdparty/justrx/3rdparty/CMakeLists.txt]=1
		[auxil/spicy/tests/Scripts/3rdparty/checkbashisms.pl]=1
		[src/cluster/websocket/auxil/CMakeLists.txt]=1
		[auxil/spicy/hilti/runtime/include/3rdparty/.clang-tidy]=1
		[auxil/spicy/hilti/runtime/include/3rdparty/ArticleEnumClass-v2]=1
		[auxil/spicy/hilti/runtime/include/3rdparty/SafeInt]=1
		[auxil/spicy/hilti/runtime/include/3rdparty/tinyformat]=1
		[auxil/spicy/hilti/runtime/include/3rdparty/any]=1  # dangling symlink; linb::any not shipped
		[auxil/spicy/hilti/runtime/include/3rdparty/ghc]=1  # dangling symlink; ghc::filesystem not shipped
	)

	local -A keep_seen=()
	local parent child
	while IFS= read -r -d '' parent; do
		[[ -d ${parent} ]] || continue
		while IFS= read -r -d '' child; do
			child=${child#./}
			if [[ -n ${keep_bundled[${child}]} ]]; then
				keep_seen[${child}]=1
				continue
			fi
			rm -rf "${child}" || die
		done < <(find "${parent}" -mindepth 1 -maxdepth 1 -print0)
	done < <(find . -depth -type d \( -name 3rdparty -o -name auxil \) -print0)

	for child in "${!keep_bundled[@]}"; do
		[[ -n ${keep_seen[${child}]} ]] ||
			die "stale keep_bundled entry: ${child}"
	done

	cmake_src_prepare

	# src_install moves the site/ tree to /etc/zeek; point the compiled-in
	# ZEEKPATH and zeek-config --site_dir there so 'zeek local' resolves.
	sed -i 's|${ZEEK_SCRIPT_INSTALL_PATH}/site |${ZEEK_ETC_INSTALL_DIR}/site |' \
		CMakeLists.txt || die
	sed -i 's|@ZEEK_SCRIPT_INSTALL_PATH@/site|@ZEEK_ETC_INSTALL_DIR@/site|' \
		cmake_templates/zeek-config.in || die
}

src_configure() {
	local mycmakeargs=(
		-DENABLE_DEBUG=$(usex debug)
		-DENABLE_JEMALLOC=$(usex jemalloc)
		-DENABLE_PERFTOOLS=$(usex tcmalloc)
		-DENABLE_STATIC=$(usex static-libs)
		-DBUILD_STATIC_BROKER=$(usex static-libs)
		-DBUILD_STATIC_BINPAC=$(usex static-libs)
		-DINSTALL_ZEEKCTL=$(usex zeekctl)
		-DINSTALL_AUX_TOOLS=$(usex tools)
		-DINSTALL_ZKG=$(usex zkg)
		-DINSTALL_ZEEK_CLIENT=$(usex zeek-client)
		-DDISABLE_PYTHON_BINDINGS=$(usex python no yes)
		# ZeekJS needs libnode, which ::gentoo's nodejs does not build.
		-DDISABLE_JAVASCRIPT=yes
		# Native Linux capture backend; pinned on rather than left to the default.
		-DDISABLE_AF_PACKET=no
		-DDISABLE_SPICY=$(usex spicy no yes)
		# Never build Spicy's benchmarks; also lets src_prepare drop the
		# vendored Google Benchmark tree.
		-DSPICY_ENABLE_BENCHMARKS=no
		-DENABLE_CLUSTER_BACKEND_ZEROMQ=$(usex zeromq)
		# The Redis storage backend otherwise auto-enables whenever hiredis is
		# found; pin it to the USE flag.
		-DENABLE_STORAGE_BACKEND_REDIS=$(usex redis)
		# Gate the otherwise-automagic GeoIP and Kerberos detection on USE flags.
		-DCMAKE_DISABLE_FIND_PACKAGE_LibMMDB=$(usex geoip2 no yes)
		-DCMAKE_DISABLE_FIND_PACKAGE_LibKrb5=$(usex kerberos no yes)
		-DPython_EXECUTABLE="${PYTHON}"
		-DZEEK_ETC_INSTALL_DIR="/etc/${PN}"
		-DZEEK_STATE_DIR="/var/lib"
		-DPY_MOD_INSTALL_DIR="$(python_get_sitedir)"
		-DBINARY_PACKAGING_MODE=true
		# Broker links the external CAF (dev-libs/zeek-caf) when CAF_ROOT is set.
		-DCAF_ROOT="${ESYSROOT}/usr"
	)

	use debug && use tcmalloc && mycmakeargs+=( -DENABLE_PERFTOOLS_DEBUG=yes )
	use zeekctl && mycmakeargs+=(
		-DZEEK_LOG_DIR="/var/log/${PN}"
		-DZEEK_SPOOL_DIR="/var/spool/${PN}"
	)

	if ! use btest; then
		mycmakeargs+=(
			-DBROKER_DISABLE_TESTS=true
			-DBROKER_DISABLE_DOC_EXAMPLES=true
			-DINSTALL_BTEST=false
			-DINSTALL_BTEST_PCAPS=false
			-DENABLE_ZEEK_UNIT_TESTS=false
		)
	fi

	cmake_src_configure
}

src_test() {
	# Mirrors upstream's ci/test.sh: compiled-in C++ unit tests, then the
	# functional baseline suite under testing/btest.

	# Subshell so zeek-path-dev.sh's ZEEKPATH export does not leak into the phase.
	pushd "${BUILD_DIR}" >/dev/null || die
	( . ./zeek-path-dev.sh && TZ=UTC ./src/zeek --test --no-skip ) \
		|| die
	popd >/dev/null || die

	# btest.cfg hard-codes 'build_dir = build' under the source root; our CMake
	# tree is out-of-source, so expose it under the name btest expects.
	ln -snf "${BUILD_DIR}" "${S}/build" || die

	# Cases that poll a killed process with kill -0 need a PID 1 that reaps:
	# against a zombie it keeps succeeding, so the zeromq-encryption ones hang
	# and cluster.websocket.cloexec-leak fails outright.
	pushd testing/btest >/dev/null || die
	../../auxil/btest/btest -b -j "$(makeopts_jobs)" \
		|| die
	popd >/dev/null || die

	# Blind spot: the in-tree build resolves utf8proc/base64 whatever the series
	# does, so a broken installed link interface passes everything above. After
	# merging, spicy-config --ldflags must list -lb64 and -lutf8proc, and
	# hilti-config --ldflags -lutf8proc; the rt archives are static-only and carry
	# those symbols undefined.
}

src_install() {
	cmake_src_install

	# Pin the entry points to the selected interpreter, not /usr/bin/env python3.
	use python && python_fix_shebang "${ED}/usr/bin"

	use python && python_optimize "${ED}"/usr/"$(get_libdir)"/zeek/python/

	keepdir \
		/var/log/"${PN}" \
		/var/spool/"${PN}"/{tmp,brokerstore,extract_files}
	use zkg && keepdir /var/lib/zkg

	# Upstream installs the spool dir world-writable (0777); tighten it.
	fperms 0755 /var/spool/"${PN}"

	# Relocate editable config out of /usr/share so reinstalls don't clobber it.
	mv "${ED}"/usr/share/zeek/site "${ED}"/etc/zeek/ || die

	if use zeekctl; then
		sed -i "s:^SitePolicyScripts.*$:SitePolicyScripts = /etc/zeek/site/local.zeek:" \
			"${ED}"/etc/zeek/zeekctl.cfg || die

		# Expire archived logs after a week (upstream keeps them forever).
		sed -i "s:^LogExpireInterval =.*:LogExpireInterval = 7day:" \
			"${ED}"/etc/zeek/zeekctl.cfg || die

		# OpenRC service wrapping "zeekctl deploy"; topology lives in node.cfg.
		newinitd "${FILESDIR}"/${PN}.initd ${PN}

		if use cron; then
			insinto /etc/cron.d
			newins "${FILESDIR}"/${PN}.crond ${PN}
		fi
	fi
	if use zkg; then
		sed -i "s:^state_dir.*$:state_dir = /var/lib/zkg:" \
			"${ED}"/etc/zeek/zkg/config || die
	fi
}
