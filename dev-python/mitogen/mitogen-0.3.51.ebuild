# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..14} )

inherit distutils-r1 pypi

DESCRIPTION="Library for writing distributed self-replicating programs"
HOMEPAGE="
	https://pypi.org/project/mitogen/
	https://mitogen.networkgenomics.com/
	https://github.com/mitogen-hq/mitogen/
"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+ansible test"
RESTRICT="!test? ( test )"

RDEPEND="ansible? ( app-admin/ansible[${PYTHON_USEDEP}] )"
BDEPEND="test? (
	dev-python/pytest-import-check[${PYTHON_USEDEP}]
	app-admin/ansible[${PYTHON_USEDEP}]
)"

python_install() {
	distutils-r1_python_install

	use ansible || return

	local sitedir plugin
	sitedir=$(python_get_sitedir)
	for plugin in mitogen mitogen_free mitogen_host_pinned mitogen_linear; do
		dosym -r \
			"${sitedir}/ansible_mitogen/plugins/strategy/${plugin}.py" \
			"${sitedir}/ansible/plugins/strategy/${plugin}.py"
	done
	python_optimize "${D}${sitedir}/ansible/plugins/strategy/"
}

python_test() {
	local sitedir
	sitedir=$(python_get_sitedir)
	local EPYTEST_IGNORE=(
		"${BUILD_DIR}/install${sitedir}/mitogen/compat/pkgutil.py"
		"${BUILD_DIR}/install${sitedir}/mitogen/imports/_py314.py"
		"${BUILD_DIR}/install${sitedir}/ansible_mitogen/plugins/connection/mitogen_kubectl.py"
	)
	epytest --import-check "${BUILD_DIR}/install${sitedir}"
}
