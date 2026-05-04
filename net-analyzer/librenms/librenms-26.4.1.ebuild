# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit bash-completion-r1 systemd

DESCRIPTION="A fully featured network monitoring system"
HOMEPAGE="https://www.librenms.org/ https://github.com/librenms/librenms"

# To regenerate the vendor tarball:
#   tar -xf ${P}.tar.gz
#   cd ${P}
#   composer install --no-dev --optimize-autoloader --ignore-platform-reqs
#   cd ..
#   XZ_OPT='-T0 -9e' tar -cJf ${P}-vendor.tar.xz ${P}/vendor
# Then upload as a release asset to vklimovs/portage-overlay.
SRC_URI="
	https://github.com/${PN}/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
"

LICENSE="GPL-3+ 0BSD Apache-2.0 BSD BSD-2 GPL-2 GPL-2+ ISC LGPL-2.1 LGPL-2.1+ LGPL-3+ MIT QPL-1.0"
SLOT="0"
KEYWORDS="~amd64"

IUSE="amqp ipmi ldap radius +redis"

RDEPEND="
	acct-group/librenms
	acct-user/librenms
	app-admin/sudo
	>=dev-lang/php-8.2:*[cli,curl,fpm,gd,mysql,mysqli,pdo,session,simplexml,snmp,sockets,ssl,unicode,xml,zip,zlib,ldap?]
	dev-php/pecl-imagick
	dev-php/pecl-memcached
	dev-python/command-runner
	dev-python/psutil
	dev-python/pymysql
	dev-python/python-dotenv
	dev-python/redis
	media-gfx/graphviz
	>=net-analyzer/fping-4.2[suid]
	net-analyzer/mtr
	net-analyzer/net-snmp
	net-analyzer/nmap
	net-analyzer/rrdtool[rrdcached]
	net-misc/whois
	sys-apps/acl
	virtual/cron
	virtual/mysql
	amqp? ( dev-php/pecl-amqp )
	ipmi? ( sys-apps/ipmitool )
	radius? ( dev-php/pecl-radius )
	redis? ( dev-db/redis )
"

LIBRENMS_HOME="/opt/librenms"
LIBRENMS_LOG="/var/log/librenms"
LIBRENMS_LIB="/var/lib/librenms"
LIBRENMS_CACHE="/var/cache/librenms"
LIBRENMS_ETC="/etc/librenms"

src_prepare() {
	default

	sed -i "s|/opt/librenms/logs|${LIBRENMS_LOG}|g" \
		misc/librenms.logrotate || die
}

src_install() {
	rm -rf .github doc licenses tests || die
	rm -f .editorconfig .git-blame-ignore-revs .php-cs-fixer.php .styleci.yml \
		LICENSE.txt mkdocs.yml package.json package-lock.json phpunit.xml \
		phpstan-baseline-deprecated.neon phpstan-baseline.neon \
		phpstan-deprecated.neon phpstan-legacy.neon phpstan.neon \
		rector.php requirements.txt vite.config.mjs || die

	dodoc AUTHORS.md CHANGELOG.md CODE_OF_CONDUCT.md CONTRIBUTING.md \
		README.md SECURITY.md
	rm -f -- *.md || die

	rm -rf cache logs rrd storage bootstrap/cache || die

	dodir "${LIBRENMS_HOME}"
	cp -a . "${ED}${LIBRENMS_HOME}/" || die

	keepdir "${LIBRENMS_LOG}"
	keepdir "${LIBRENMS_LIB}"/{rrd,storage/{app/public,framework/{cache/data,sessions,testing,views},logs}}
	keepdir "${LIBRENMS_CACHE}"/{bootstrap,misc}
	keepdir "${LIBRENMS_ETC}"

	dosym -r "${LIBRENMS_LOG}" "${LIBRENMS_HOME}/logs"
	dosym -r "${LIBRENMS_LIB}/rrd" "${LIBRENMS_HOME}/rrd"
	dosym -r "${LIBRENMS_LIB}/storage" "${LIBRENMS_HOME}/storage"
	dosym -r "${LIBRENMS_CACHE}/bootstrap" "${LIBRENMS_HOME}/bootstrap/cache"
	dosym -r "${LIBRENMS_CACHE}/misc" "${LIBRENMS_HOME}/cache"
	dosym -r "${LIBRENMS_ETC}/.env" "${LIBRENMS_HOME}/.env"
	dosym -r "${LIBRENMS_ETC}/config.php" "${LIBRENMS_HOME}/config.php"

	dosym -r "${LIBRENMS_HOME}/lnms" /usr/bin/lnms

	insinto /etc/logrotate.d
	newins misc/librenms.logrotate librenms

	newbashcomp misc/lnms-completion.bash lnms

	insinto /etc/cron.d
	newins dist/librenms.cron librenms

	systemd_dounit dist/librenms-scheduler.service \
		dist/librenms-scheduler.timer

	insinto /etc/mysql/mariadb.d
	doins "${FILESDIR}/80-librenms.cnf"

	fowners -R librenms:librenms \
		"${LIBRENMS_LOG}" "${LIBRENMS_LIB}" "${LIBRENMS_CACHE}" \
		"${LIBRENMS_ETC}"
	fperms 0750 "${LIBRENMS_LOG}" "${LIBRENMS_LIB}" "${LIBRENMS_CACHE}" \
		"${LIBRENMS_ETC}"
}

pkg_postinst() {
	elog
	elog "Configure your database (MariaDB recommended) before first use:"
	elog "  CREATE DATABASE librenms"
	elog "    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
	elog "  CREATE USER 'librenms'@'localhost' IDENTIFIED BY '<password>';"
	elog "  GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'localhost';"
	elog "  FLUSH PRIVILEGES;"
	elog
	elog "Then run:"
	elog "  emerge --config =${CATEGORY}/${PF}"
	elog
	elog "Layout summary (FHS-aligned, code dir is immutable):"
	elog "  ${LIBRENMS_HOME}             code (root-owned)"
	elog "  ${LIBRENMS_ETC}/.env         credentials, mode 0640"
	elog "  ${LIBRENMS_ETC}/config.php   optional override config"
	elog "  ${LIBRENMS_LIB}/{rrd,storage}  RRD + Laravel storage"
	elog "  ${LIBRENMS_CACHE}/{bootstrap,misc}  regenerable caches"
	elog "  ${LIBRENMS_LOG}              application logs"
	elog
	elog "Web docroot: ${LIBRENMS_HOME}/html"
	elog "Reference: https://docs.librenms.org/Installation/"
	elog
}

pkg_config() {
	if [[ ! -f ${EROOT}${LIBRENMS_ETC}/.env ]]; then
		einfo "Seeding ${LIBRENMS_ETC}/.env from .env.example"
		cp "${EROOT}${LIBRENMS_HOME}/.env.example" \
			"${EROOT}${LIBRENMS_ETC}/.env" || die
		chown librenms:librenms "${EROOT}${LIBRENMS_ETC}/.env" || die
		chmod 0640 "${EROOT}${LIBRENMS_ETC}/.env" || die
	fi

	cd "${EROOT}${LIBRENMS_HOME}" || die

	einfo "Generating Laravel APP_KEY (idempotent)"
	sudo -u librenms -- php artisan key:generate --force || die

	einfo "Running database migrations"
	sudo -u librenms -- ./lnms migrate --force || die

	einfo "Validating installation"
	sudo -u librenms -- ./validate.php \
		|| ewarn "Validation reported issues; review the output above."

	einfo "Done."
}
