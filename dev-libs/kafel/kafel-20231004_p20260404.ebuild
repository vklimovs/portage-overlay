# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs

# Tracks upstream HEAD rather than the submodule app-misc/nsjail pins: nsjail
# uses only the stable kafel_ctx_t API and binds the subslot, so a bump needs no
# nsjail edit. But an API-compatible kafel can still emit different BPF, so a
# bump is not done until nsjail is re-emerged and a KILL{mkdir} policy is
# confirmed to kill while ALLOW{mkdir} passes.
COMMIT="18f207428068a50f2c35706c5d0b21f53c769016"

DESCRIPTION="Seccomp-bpf policy language and compiler library"
HOMEPAGE="https://github.com/google/kafel"
SRC_URI="https://github.com/google/${PN}/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}-${COMMIT}"

LICENSE="Apache-2.0"
SLOT="0/1"
KEYWORDS="~amd64"
IUSE="static-libs"

BDEPEND="
	app-alternatives/lex
	app-alternatives/yacc
"

PATCHES=( "${FILESDIR}/${P}-respect-user-flags.patch" )

src_compile() {
	tc-export CC AR LD OBJCOPY OBJDUMP
	emake
}

src_install() {
	newlib.so libkafel.so libkafel.so.1
	dosym libkafel.so.1 "/usr/$(get_libdir)/libkafel.so"
	use static-libs && dolib.a libkafel.a

	doheader include/kafel.h

	cat > "${T}"/kafel.pc <<-EOF || die
		prefix=${EPREFIX}/usr
		libdir=\${prefix}/$(get_libdir)
		includedir=\${prefix}/include

		Name: kafel
		Description: ${DESCRIPTION}
		Version: ${PV}
		Libs: -L\${libdir} -lkafel
		Cflags: -I\${includedir}
	EOF

	insinto "/usr/$(get_libdir)/pkgconfig"
	doins "${T}"/kafel.pc
}
