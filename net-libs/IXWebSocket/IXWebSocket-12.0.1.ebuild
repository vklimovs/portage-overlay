# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Lightweight C++ WebSocket and HTTP client and server library"
HOMEPAGE="https://github.com/machinezone/IXWebSocket"
SRC_URI="https://github.com/machinezone/IXWebSocket/archive/v${PV}.tar.gz
	-> ${P}.tar.gz"
S="${WORKDIR}/IXWebSocket-${PV}"

LICENSE="BSD"
# Subslot tracks the SONAME (libixwebsocket.so.$SLOT, from CMake project VERSION,
# no explicit SOVERSION) so := consumers rebuild on ABI changes; re-derive with
# `objdump -p` on each bump.
SLOT="0/12.0.1"
KEYWORDS="~amd64"

RDEPEND="
	dev-libs/openssl:=
	virtual/zlib:=
"
DEPEND="${RDEPEND}"

src_configure() {
	local mycmakeargs=(
		-DUSE_TLS=ON
		-DUSE_OPEN_SSL=ON
		-DUSE_ZLIB=ON
		# Keep off: both pull spdlog via FetchContent (network) at build time.
		-DUSE_WS=OFF
		-DUSE_TEST=OFF
	)
	cmake_src_configure
}
