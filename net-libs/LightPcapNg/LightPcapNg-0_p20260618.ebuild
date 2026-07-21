# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

COMMIT="b36c701a2b4f48714e9c23a993c2758717c84123"

DESCRIPTION="Light PcapNg read, write and manipulation API"
HOMEPAGE="https://github.com/Technica-Engineering/LightPcapNg"
SRC_URI="https://github.com/Technica-Engineering/LightPcapNg/archive/${COMMIT}.tar.gz
	-> ${P}.tar.gz"
S="${WORKDIR}/LightPcapNg-${COMMIT}"

LICENSE="MIT"
SLOT="0/0"
KEYWORDS="~amd64"

src_prepare() {
	sed -i '/^add_library(light_pcapng/a set_target_properties(light_pcapng PROPERTIES SOVERSION 0)' \
		CMakeLists.txt || die
	sed -i '/target_compile_options(light_pcapng PRIVATE -Werror)/d' CMakeLists.txt || die
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_SHARED_LIBS=ON
		-DBUILD_TESTING=OFF
		-DCMAKE_INSTALL_LIBDIR="$(get_libdir)"
		-DLIGHT_USE_ZLIB=OFF
		-DLIGHT_USE_ZSTD=OFF
	)
	cmake_src_configure
}
