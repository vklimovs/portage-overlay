# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit flag-o-matic

DESCRIPTION="rsync version needed for BackupPC 4.x"
HOMEPAGE="https://github.com/backuppc/rsync-bpc"
SRC_URI="https://github.com/backuppc/${PN}/archive/${PV}/${PV}.tar.gz
	-> ${P}.tar.gz"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 hppa ~ia64 ~m68k ~mips ppc ppc64 ~riscv
	s390 sparc x86 ~x64-cygwin ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos
	~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="acl examples iconv ipv6 static system-zlib xattr"

LIB_DEPEND="acl? ( virtual/acl[static-libs(+)] )
	system-zlib? ( sys-libs/zlib[static-libs(+)] )
	xattr? ( kernel_linux? ( sys-apps/attr[static-libs(+)] ) )
	>=dev-libs/popt-1.5[static-libs(+)]"
RDEPEND="!static? ( ${LIB_DEPEND//\[static-libs(+)]} )
	iconv? ( virtual/libiconv )"
DEPEND="${RDEPEND}
	static? ( ${LIB_DEPEND} )"

src_configure() {
	use static && append-ldflags -static
	local myeconfargs=(
		--with-rsyncd-conf="${EPREFIX}"/etc/rsyncd.conf
		--without-included-popt
		$(use_enable acl acl-support)
		$(use_enable iconv)
		$(use_enable ipv6)
		$(use_with !system-zlib included-zlib)
		$(use_enable xattr xattr-support)
	)

	econf "${myeconfargs[@]}"
}

src_install() {
	emake DESTDIR="${D}" install

	dodoc NEWS README TODO tech_report.tex

	# Install the useful contrib scripts
	if use examples ; then
		exeinto /usr/share/"${PN}"
		doexe support/*
		rm -f "${ED}"/usr/share/"${PN}"/{Makefile*,*.c}
	fi
}

pkg_postinst() {
	if use system-zlib ; then
		ewarn "Using system-zlib is incompatible with <rsync-3.1.1 when"
		ewarn "using the --compress option."
		ewarn
		ewarn "When syncing with >=rsync-3.1.1 built with bundled zlib,"
		ewarn "and the --compress option, add --new-compress (-zz)."
	fi
}
