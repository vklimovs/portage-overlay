# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs

DESCRIPTION="Process isolation tool using Linux namespaces, rlimits and seccomp-bpf"
HOMEPAGE="https://nsjail.dev/"
SRC_URI="https://github.com/google/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="
	dev-libs/kafel:=
	dev-libs/protobuf:=
	dev-libs/libnl:3
"

RDEPEND="${DEPEND}"

BDEPEND="
	dev-libs/protobuf
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}/${P}-respect-user-flags.patch"
	"${FILESDIR}/${P}-system-kafel.patch"
)

src_compile() {
	emake CC="$(tc-getCC)" CXX="$(tc-getCXX)"
}

src_install() {
	dobin nsjail
	dodoc README.md
	dodoc -r configs
}
