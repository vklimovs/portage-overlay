# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs

MY_COMMIT="f8381f3331d9c56a9792f9b4a35f61c41108c39e"

DESCRIPTION="Library and command-line tool for highway hash functions"
HOMEPAGE="https://github.com/google/highwayhash"
SRC_URI="https://github.com/google/highwayhash/archive/${MY_COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/highwayhash-${MY_COMMIT}"

LICENSE="Apache-2.0"
SLOT="0/0"
KEYWORDS="~amd64"
IUSE="static-libs"

src_compile() {
	emake CXX="$(tc-getCXX)" AR="$(tc-getAR)" lib/libhighwayhash.a lib/libhighwayhash.so
}

src_install() {
	dolib.so lib/libhighwayhash.so.0
	dosym libhighwayhash.so.0 /usr/$(get_libdir)/libhighwayhash.so

	use static-libs && dolib.a lib/libhighwayhash.a

	insinto /usr/include/highwayhash
	doins highwayhash/*.h

	insinto /usr/$(get_libdir)/pkgconfig
	newins - highwayhash.pc <<-EOF
		prefix=${EPREFIX}/usr
		exec_prefix=\${prefix}
		libdir=\${exec_prefix}/$(get_libdir)
		includedir=\${prefix}/include

		Name: highwayhash
		Description: ${DESCRIPTION}
		Version: ${PV}
		Libs: -L\${libdir} -lhighwayhash
		Cflags: -I\${includedir}
	EOF
}
