# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

MY_PN="phpLDAPadmin"

# To generate the vendor tarball:
#   tar -xf phpldapadmin-${PV}.tar.gz
#   cd phpLDAPadmin-${PV}
#   composer install --no-dev --optimize-autoloader
#   npm install && npm run production
#   cd ..
#   tar -cJf phpldapadmin-${PV}-vendor.tar.xz \
#       phpLDAPadmin-${PV}/vendor/ \
#       phpLDAPadmin-${PV}/public/js/ \
#       phpLDAPadmin-${PV}/public/css/ \
#       phpLDAPadmin-${PV}/public/fonts/

DESCRIPTION="A web-based tool for managing LDAP servers"
HOMEPAGE="https://phpldapadmin.org https://github.com/leenooks/phpLDAPadmin"
SRC_URI="https://github.com/leenooks/${MY_PN}/archive/${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/leenooks/${MY_PN}/archive/${PV}-vendor.tar.gz
		-> ${P}-vendor.tar.xz"

S="${WORKDIR}/${MY_PN}-${PV}"

LICENSE="GPL-2"
SLOT="${PVR}"
KEYWORDS="~amd64"

# PHP extensions required by phpLDAPadmin (ext-fileinfo, ext-iconv) and
# Laravel 12 (ext-mbstring/unicode, ext-openssl/ssl) and for running
# artisan commands (cli) and serving via PHP-FPM (fpm).
RDEPEND="
	>=dev-lang/php-8.4:*[cli,fpm,ldap,ssl,unicode]
	virtual/httpd-php
"

PLA_HOME="/var/lib/${P}"

src_compile() {
	return
}

src_install() {
	# Remove developer/build-only files not needed at runtime
	rm -rf .github .gitea docker tests || die
	rm -f .editorconfig .gitattributes .gitignore phpunit.xml \
		package.json package-lock.json webpack.mix.js || die

	insinto "${PLA_HOME}"
	doins -r app bootstrap config database public resources routes \
		storage templates
	doins artisan composer.json composer.lock

	# Rename the example env file to the live config
	newins .env.example .env

	# artisan is a PHP CLI script that must be executable
	fperms 0755 "${PLA_HOME}/artisan"

	# Laravel requires these directories to be writable by the web server.
	# keepdir ensures they exist even when empty (git does not track empty dirs).
	keepdir \
		"${PLA_HOME}"/storage/app/public \
		"${PLA_HOME}"/storage/framework/cache/data \
		"${PLA_HOME}"/storage/framework/sessions \
		"${PLA_HOME}"/storage/framework/testing \
		"${PLA_HOME}"/storage/framework/views \
		"${PLA_HOME}"/storage/logs \
		"${PLA_HOME}"/bootstrap/cache
}

pkg_postinst() {
	einfo "phpLDAPadmin has been installed to ${PLA_HOME}."
	einfo
	einfo "Configure your web server to use ${PLA_HOME}/public/ as"
	einfo "the document root. Example Nginx config:"
	einfo "  root ${PLA_HOME}/public;"
	einfo "  index index.php;"
	einfo "  location / { try_files \$uri \$uri/ /index.php?\$query_string; }"
	einfo
	einfo "Edit ${PLA_HOME}/.env to set your LDAP server details:"
	einfo "  LDAP_HOST=ldap.example.com"
	einfo "  LDAP_USERNAME=cn=admin,dc=example,dc=com"
	einfo "  LDAP_PASSWORD=secret"
	einfo
	einfo "Run 'emerge --config =${CATEGORY}/${PF}' to finish setup."
}

pkg_config() {
	local pla_home="${EROOT}${PLA_HOME}"

	einfo "Generating application encryption key..."
	php "${pla_home}/artisan" key:generate || die

	einfo "Caching configuration for production..."
	php "${pla_home}/artisan" optimize || die

	einfo "Setting permissions on writable directories..."
	chown -R root:apache \
		"${pla_home}"/storage \
		"${pla_home}"/bootstrap/cache || die
	chmod -R ug+rwX,o-rwx \
		"${pla_home}"/storage \
		"${pla_home}"/bootstrap/cache || die

	einfo "All done."
}
