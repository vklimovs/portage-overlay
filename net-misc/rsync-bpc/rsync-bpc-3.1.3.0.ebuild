# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic

DESCRIPTION="rsync version needed for BackupPC 4.x"
HOMEPAGE="https://github.com/backuppc/rsync-bpc"
SRC_URI="https://github.com/backuppc/${PN}/archive/${PV}/${PV}.tar.gz
	-> ${P}.tar.gz"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE="acl examples iconv +ipv6 static system-zlib xattr"

LIB_DEPEND="acl? ( virtual/acl[static-libs(+)] )
	system-zlib? ( virtual/zlib[static-libs(+)] )
	xattr? ( kernel_linux? ( sys-apps/attr[static-libs(+)] ) )
	>=dev-libs/popt-1.5[static-libs(+)]"
RDEPEND="!static? ( ${LIB_DEPEND//\[static-libs(+)]} )
	iconv? ( virtual/libiconv )"
DEPEND="${RDEPEND}
	static? ( ${LIB_DEPEND} )"

PATCHES=(
	"${FILESDIR}"/${P}-fix-gcc15.patch
)

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

src_test() {
	emake wildtest
	local opts
	for opts in "" "-x1" "-x1 -e1" "-x1 -e1se" "-x2" "-x2 -ese" \
			"-x3" "-x3 -e1" "-x4" "-x4 -e2e" "-x5" "-x5 -es"; do
		local out
		out=$(./wildtest ${opts} wildtest.txt) || die "wildtest ${opts} failed"
		[[ ${out} == "No wildmatch errors found." ]] \
			|| die "wildtest ${opts}: ${out}"
	done
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
