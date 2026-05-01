# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module shell-completion systemd toolchain-funcs

DESCRIPTION="One-stop, integrated solution for ZFS replication"
HOMEPAGE="https://zrepl.github.io https://github.com/zrepl/zrepl"

# To generate the vendor tarball:
#   tar -xf ${P}.tar.gz
#   cd ${P}
#   go mod vendor
#   cd ..
#   tar -caf ${P}-vendor.tar.xz ${P}/vendor
SRC_URI="
	https://github.com/zrepl/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
"

# zrepl itself
LICENSE="MIT"
# Vendored package licenses
LICENSE+=" Apache-2.0 BSD ISC LGPL-3+ MPL-2.0"
SLOT="0"
KEYWORDS="~amd64"
BDEPEND=">=dev-lang/go-1.24:="

DOCS=( README.md )

src_prepare() {
	default
	sed -i 's|/usr/local/bin/zrepl|/usr/bin/zrepl|g' \
		dist/systemd/zrepl.service || die
}

src_compile() {
	local version_pkg="github.com/zrepl/zrepl/internal/version"
	ego build \
		-mod=vendor \
		-trimpath \
		-ldflags "-X ${version_pkg}.zreplVersion=${PV}" \
		-o "${PN}" .

	if ! tc-is-cross-compiler; then
		./"${PN}" gencompletion bash "${PN}.bash" || die
		./"${PN}" gencompletion zsh "${PN}.zsh" || die
	fi
}

src_install() {
	dobin "${PN}"
	einstalldocs

	if ! tc-is-cross-compiler; then
		newbashcomp "${PN}.bash" "${PN}"
		newzshcomp "${PN}.zsh" "_${PN}"
	else
		ewarn "Shell completions not installed (cross-compiling)."
		ewarn "Run '${PN} gencompletion <bash|zsh> <outfile>' manually."
	fi

	keepdir /etc/zrepl

	docinto examples
	dodoc -r internal/config/samples

	newinitd "${FILESDIR}/${PN}.initd" "${PN}"
	systemd_dounit dist/systemd/zrepl.service
}
