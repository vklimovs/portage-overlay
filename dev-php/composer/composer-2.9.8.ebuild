# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit bash-completion-r1 git-r3

DESCRIPTION="Dependency manager for PHP"
HOMEPAGE="https://getcomposer.org https://github.com/composer/composer"

# To regenerate the vendor tarball:
#   git clone -b ${PV} https://github.com/composer/composer ${P}
#   ( cd ${P} && composer install --no-dev --optimize-autoloader )
#   XZ_OPT='-T0 -9' tar -caf ${P}-vendor.tar.xz ${P}/vendor/
SRC_URI="https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz"

EGIT_REPO_URI="https://github.com/${PN}/${PN}"
EGIT_COMMIT="82a2fbd1372a98d7915cfb092acf05207d9b4113"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="doc"

RDEPEND=">=dev-lang/php-8.2:*[cli,phar]"
BDEPEND="${RDEPEND}"

DOCS=( CHANGELOG.md README.md )

src_unpack() {
	git-r3_src_unpack
	unpack "${P}-vendor.tar.xz"
}

src_compile() {
	php -d memory_limit=-1 -d phar.readonly=0 bin/compile || die
	mv composer.phar composer || die
	php composer completion bash > completion.bash || die
}

src_test() {
	if has usersandbox ${FEATURES} || has network-sandbox ${FEATURES}; then
		ewarn "Skipping smoke test: requires writable user namespaces and"
		ewarn "packagist.org network access, both denied by"
		ewarn "FEATURES=usersandbox / FEATURES=network-sandbox."
		return 0
	fi

	local td="${T}/integration-test"
	mkdir "${td}" || die
	cd "${td}" || die
	php "${S}/composer" init \
		--no-interaction \
		--type=project \
		--name='gentoo/test' \
		--description='Composer ebuild integration test' \
		--license='GPL-3.0-or-later' \
		--require='symfony/console:*' || die
	php "${S}/composer" update --no-interaction --no-progress --prefer-dist || die
	php "${S}/composer" validate --no-interaction || die
}

src_install() {
	dobin composer
	newbashcomp completion.bash composer
	einstalldocs
	use doc && dodoc -r doc
}
