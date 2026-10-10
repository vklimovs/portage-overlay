# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_SINGLE_IMPL=1
DISTUTILS_USE_PEP517=uv-build
PYTHON_COMPAT=( python3_{11..14} )

inherit distutils-r1

DESCRIPTION="Python tool to configure host network interfaces declaratively"
HOMEPAGE="https://ifstate.net/"
MY_PV="${PV/_/-}"
SRC_URI="https://codeberg.org/routerkit/ifstate/archive/${MY_PV}.tar.gz -> ${P}.tar.gz"

S="${WORKDIR}/${PN}"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	$(python_gen_cond_dep '
		dev-python/jsonschema[${PYTHON_USEDEP}]
		dev-python/pygments[${PYTHON_USEDEP}]
		dev-python/pyroute2[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/setproctitle[${PYTHON_USEDEP}]
	')
"

PATCHES=(
	"${FILESDIR}/${P}-ethtool-bool-options.patch"
	"${FILESDIR}/${P}-tun-default-mac.patch"
	"${FILESDIR}/${P}-altnames-del-crash.patch"
	"${FILESDIR}/${P}-address-dynamic-renew.patch"
	"${FILESDIR}/${P}-link-address-missing-link.patch"
	"${FILESDIR}/${P}-neighbour-state-filter.patch"
	"${FILESDIR}/${P}-clear-altnames.patch"
)

DOCS=( README.md CHANGELOG.md )

EPYTEST_PLUGINS=()
distutils_enable_tests pytest

python_test() {
	epytest -o addopts= src
}

python_install() {
	distutils-r1_python_install
	local sitedir="${D}$(python_get_sitedir)"
	rm -r "${sitedir}"/ifstate/tests "${sitedir}"/libifstate/{tests,parser/tests,conftest.py,__pycache__/conftest.*} || die
}

python_install_all() {
	distutils-r1_python_install_all
	newinitd "${FILESDIR}/${PN}.initd" "${PN}"
	keepdir /etc/ifstate
}
