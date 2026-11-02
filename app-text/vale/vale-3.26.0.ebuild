# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..15} )

inherit go-module optfeature python-any-r1

DESCRIPTION="Markup-aware linter for prose"
HOMEPAGE="https://vale.sh/ https://github.com/vale-cli/vale"

# go mod vendor skips directories without Go files, and php's tree-sitter
# scanner includes headers from one.
# To generate the vendor tarball:
#   tar -xf ${P}.tar.gz
#   cd ${P}
#   go mod vendor
#   cp -r --no-preserve=mode "$(go list -mod=mod -m -f '{{.Dir}}' \
#       github.com/smacker/go-tree-sitter)"/php/tree_sitter \
#       vendor/github.com/smacker/go-tree-sitter/php
#   cd ..
#   tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
#       -cf - ${P}/vendor | xz -9e >"${P}-vendor.tar.xz"
SRC_URI="
	https://github.com/vale-cli/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
"

# vale itself
LICENSE="MIT"
# Vendored package licenses
LICENSE+=" Apache-2.0 BSD BSD-2 ISC"
SLOT="0"
KEYWORDS="~amd64"
IUSE="test"
RESTRICT="!test? ( test )"

BDEPEND="
	>=dev-lang/go-1.25.7
	test? (
		$(python_gen_any_dep 'dev-python/docutils[${PYTHON_USEDEP}]')
		dev-libs/libxslt
		dev-ruby/asciidoctor
	)
"

python_check_deps() {
	python_has_version "dev-python/docutils[${PYTHON_USEDEP}]"
}

pkg_setup() {
	use test && python-any-r1_pkg_setup
}

src_compile() {
	ego build \
		-mod=vendor \
		-trimpath \
		-ldflags "-X main.version=${PV}" \
		-o "${PN}" ./cmd/vale
}

src_test() {
	# Vale reads rst2html's shebang to find the Python with Docutils, and
	# python-exec's wrapper names none. TestSymlinkFixture runs `vale` by name.
	local -x PATH="${EPREFIX}/usr/lib/python-exec/${EPYTHON}:${S}:${PATH}"
	# These fetch from GitHub.
	ego test -mod=vendor \
		-skip '^TestLibrary$|^TestNoPkgFound$|^TestScenarios$/^pkg$' \
		./...
}

src_install() {
	dobin "${PN}"
	einstalldocs
}

pkg_postinst() {
	optfeature "AsciiDoc support" dev-ruby/asciidoctor
	optfeature "reStructuredText support" dev-python/docutils
	optfeature "XML support" dev-libs/libxslt
}
