# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

COMMIT="42702392d2c0b3e03efcfbe6095816137cc2a89a"

DESCRIPTION="Light PcapNg read, write and manipulation API"
HOMEPAGE="https://github.com/Technica-Engineering/LightPcapNg"
SRC_URI="https://github.com/Technica-Engineering/LightPcapNg/archive/${COMMIT}.tar.gz
	-> ${P}.tar.gz"
S="${WORKDIR}/LightPcapNg-${COMMIT}"

LICENSE="MIT"
SLOT="0/0"
KEYWORDS="~amd64"
IUSE="test"
RESTRICT="!test? ( test )"

src_prepare() {
	local soversion='set_target_properties(light_pcapng PROPERTIES SOVERSION 0)'
	sed -i "/^add_library(light_pcapng/a ${soversion}" CMakeLists.txt || die
	sed -i '/target_compile_options(light_pcapng PRIVATE -Werror)/d' \
		CMakeLists.txt || die
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_SHARED_LIBS=ON
		-DBUILD_TESTING=$(usex test)
		-DCMAKE_INSTALL_LIBDIR="$(get_libdir)"
		-DLIGHT_USE_ZLIB=OFF
		-DLIGHT_USE_ZSTD=OFF
	)
	cmake_src_configure
}
