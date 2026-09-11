# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

# Past 12.0.1 because net-analyzer/zeek >=8.2.2 calls IXSocketServer::
# setCloseOnExec(), added after the release; upstream has not tagged since. The
# snapshot also carries the HttpServer path-traversal fix (upstream #608) and
# the first correct SOVERSION (#607). ${PV}'s _pYYYYMMDD is this commit's date.
COMMIT="5da103b0da9183757301ea1676b26795a996e443"

DESCRIPTION="Lightweight C++ WebSocket and HTTP client and server library"
HOMEPAGE="https://github.com/machinezone/IXWebSocket"
SRC_URI="https://github.com/machinezone/IXWebSocket/archive/${COMMIT}.tar.gz
	-> ${P}.tar.gz"
S="${WORKDIR}/IXWebSocket-${COMMIT}"

LICENSE="BSD"
# Subslot tracks the SONAME (libixwebsocket.so.$SLOT). Upstream set SOVERSION to
# the major only in #607, so this is 12 where 12.0.1 carried the full version;
# re-derive with `objdump -p` on each bump.
SLOT="0/12"
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
		# The ws CLI has no consumer here, and the unit tests dial external hosts.
		# Neither downloads anything any more (upstream #605 dropped FetchContent).
		-DUSE_WS=OFF
		-DUSE_TEST=OFF
	)
	cmake_src_configure
}
