# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit autotools flag-o-matic toolchain-funcs

DESCRIPTION="A set of tools to collect and process netflow data"
HOMEPAGE="https://github.com/phaag/nfdump"
SRC_URI="https://github.com/phaag/nfdump/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0/${PV}"
KEYWORDS="~amd64 ~x86"
IUSE="debug ftconv jnat nfpcapd nfprofile readpcap"

COMMON_DEPEND="app-arch/bzip2:=
	virtual/zlib:=
	elibc_musl? ( sys-libs/fts-standalone )
	ftconv? ( net-analyzer/flow-tools:= )
	nfpcapd? ( net-libs/libpcap:= )
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

src_install() {
	default

	find "${ED}" -name '*.la' -delete || die

	newinitd "${FILESDIR}"/nfcapd.initd nfcapd
	newconfd "${FILESDIR}"/nfcapd.confd nfcapd
}
