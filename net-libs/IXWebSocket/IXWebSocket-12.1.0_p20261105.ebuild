# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

# Past 12.1.0 because before upstream #618 a TLS server busy-loops SSL_accept()
# on its only accept thread with no deadline, so one TCP peer that never sends a
# ClientHello locks everyone out of net-analyzer/zeek's TLS WebSocket API.
# ${PV}'s _pYYYYMMDD is this commit's date.
COMMIT="4ce4f871a9ae324dfbe9b84cbf59f9ba34510ab2"

DESCRIPTION="Lightweight C++ WebSocket and HTTP client and server library"
HOMEPAGE="https://github.com/machinezone/IXWebSocket"
SRC_URI="https://github.com/machinezone/IXWebSocket/archive/${COMMIT}.tar.gz
	-> ${P}.tar.gz"
S="${WORKDIR}/IXWebSocket-${COMMIT}"

LICENSE="BSD"
# Upstream breaks ABI under the libixwebsocket.so.12 SONAME (12.1.0 made
# Socket::isReadyToWrite() virtual; later commits grow ix::WebSocket), so the
# subslot is ${PV} and every bump rebuilds consumers.
SLOT="0/12.1.0_p20261105"
KEYWORDS="~amd64"

RDEPEND="
	dev-libs/openssl:=
	virtual/zlib:=
"
DEPEND="${RDEPEND}"

src_prepare() {
	# CLI11 and Catch2, consumed only by ws and the tests.
	rm -r third_party || die
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DUSE_TLS=ON
		-DUSE_OPEN_SSL=ON
		-DUSE_ZLIB=ON
		# The ws CLI has no consumer here. The unit suite runs offline since
		# upstream #619, but needs its vendored Catch2 unbundled first.
		-DUSE_WS=OFF
		-DUSE_TEST=OFF
	)
	cmake_src_configure
}
