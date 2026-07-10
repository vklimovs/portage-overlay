# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs

COMMIT="f8381f3331d9c56a9792f9b4a35f61c41108c39e"

DESCRIPTION="Fast strong hash functions: SipHash and HighwayHash"
HOMEPAGE="https://github.com/google/highwayhash"
SRC_URI="https://github.com/google/highwayhash/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/highwayhash-${COMMIT}"

LICENSE="Apache-2.0"
SLOT="0/0"
KEYWORDS="~amd64"
IUSE="static-libs test"
RESTRICT="!test? ( test )"

src_prepare() {
	default
	# Upstream force-appends -O3 (override CXXFLAGS +=), overriding the user's
	# -O level; drop it so CXXFLAGS wins. SIMD comes from per-object -mavx2/
	# -msse4.1, independent of -O level.
	sed -i 's/ -O3//' Makefile || die
}

src_compile() {
	emake CXX="$(tc-getCXX)" AR="$(tc-getAR)" lib/libhighwayhash.a lib/libhighwayhash.so
}

src_test() {
	emake CXX="$(tc-getCXX)" AR="$(tc-getAR)" \
		bin/sip_hash_test bin/highwayhash_test bin/vector_test
	local t
	for t in sip_hash_test highwayhash_test vector_test; do
		bin/${t} || die
	done
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
		Version: ${PV#0_p}
		Libs: -L\${libdir} -lhighwayhash
		Cflags: -I\${includedir}
	EOF
}
