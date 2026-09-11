# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit autotools flag-o-matic toolchain-funcs

DESCRIPTION="A set of tools to collect and process netflow data"
HOMEPAGE="https://github.com/phaag/nfdump"
SRC_URI="https://github.com/phaag/nfdump/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0/1.7.10"
KEYWORDS="~amd64 ~x86"
IUSE="debug ftconv jnat nfpcapd nfprofile readpcap test"
RESTRICT="!test? ( test )"

# lz4 and zstd are detected by pkg-config with no way to say no: found means
# linked, and for lz4 missing means silently compiling the copy vendored under
# src/libnffile/compress. Both are unconditional here so neither outcome is left
# to what happens to be installed. zlib is genuinely optional -- only libft
# (ftconv) requires it, and nfpcapd uses it to read gzipped pcaps.
COMMON_DEPEND="app-arch/bzip2:=
	app-arch/lz4:=
	app-arch/zstd:=
	elibc_musl? ( sys-libs/fts-standalone )
	ftconv? (
		net-analyzer/flow-tools:=
		virtual/zlib:=
	)
	nfpcapd? (
		net-libs/libpcap:=
		virtual/zlib:=
	)
	nfprofile? ( net-analyzer/rrdtool:= )
	readpcap? ( net-libs/libpcap:= )
"

DEPEND="${COMMON_DEPEND}"

BDEPEND="app-alternatives/yacc
	sys-devel/flex
"

RDEPEND="${COMMON_DEPEND}
	acct-group/nfcapd
	acct-user/nfcapd
"

DOCS=( AUTHORS ChangeLog README.md )

src_prepare() {
	default

	# Automake pulls these in only in the !HAVE_LZ4 branch, so with the dependency
	# above they are dead -- and deleting them turns a failed lz4 detection into a
	# missing-source build failure instead of a bundled lz4 nobody notices.
	rm src/libnffile/compress/lz4*.[ch] || die

	eautoreconf
}

src_configure() {
	tc-export CC

	# bug #853763
	use elibc_musl && append-libs "-lfts"

	local myeconfargs=(
		$(usex debug --enable-devel '')
		$(usex ftconv --enable-ftconv '')
		$(usex jnat --enable-jnat '')
		$(usex nfpcapd --enable-nfpcapd '')
		$(usex nfprofile --enable-nfprofile '')
		$(usex readpcap --enable-readpcap '')
	)

	econf "${myeconfargs[@]}"
}

src_test() {
	# The cases share one generated dummy_flows.nf: runprepare.sh writes it, the
	# per-codec cases read it, runtest.sh consumes and deletes it. In parallel
	# they race and all but nftest fail.
	emake -j1 check
}

src_install() {
	default

	find "${ED}" -name '*.la' -delete || die

	newinitd "${FILESDIR}"/nfcapd.initd nfcapd
	newconfd "${FILESDIR}"/nfcapd.confd nfcapd
}
