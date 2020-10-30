# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit perl-module webapp

MY_P=${P/_/}
DESCRIPTION="Graphical netflow analyzer using nfdump tools"
HOMEPAGE="http://nfsen.sourceforge.net/"
SRC_URI="https://sourceforge.net/projects/nfsen/files/stable/${MY_P}/${MY_P}.tar.gz"
LICENSE="BSD"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND="acct-group/nfsen
	acct-user/nfsen
	dev-perl/MailTools
	dev-perl/Socket6
	>=net-analyzer/nfdump-1.6.5[nfprofile]
	>dev-lang/php-4.1[sockets]
	net-analyzer/rrdtool[graph,perl]"

S=${WORKDIR}/${MY_P}

PATCHES=(
	"${FILESDIR}"/"${P}"-profileadmin.php.patch
	"${FILESDIR}"/"${P}"-rrd-version.patch
)

src_prepare() {
	default
	perl_set_version
	local PERL="/usr/bin/perl"
	local LIBEXECDIR="${VENDOR_LIB}/${PN}"
	local CONFDIR="/etc/${PN}"
	local BASEDIR="/var/lib/${PN}"
	local BINDIR="/usr/bin"
	local HTMLDIR="/var/www/localhost/${PN}"
	local DOCDIR="/usr/share/doc/${MY_P}"
	local PIDDIR="/run/${PN}"
	local PREFIX="/usr/bin"
	local COMMSOCKET="\$PIDDIR/${PN}.sock"
	local USER="${PN}"
	local WWWUSER="${PN}"
	local WWWGROUP="${PN}"

	find . -type f -exec sed -i "s:%%PERL%%:${PERL}:" {} \;
	find . -type f -exec sed -i "s:%%LIBEXECDIR%%:${LIBEXECDIR}:" {} \;
	find . -type f -exec sed -i "s:%%CONFDIR%%:${CONFDIR}:" {} \;

	sed -e "s:^\$BASEDIR.*:\$BASEDIR=\"${BASEDIR}\";:" \
		-e "s:^\$BINDIR.*:\$BINDIR=\"${BINDIR}\";:" \
		-e "s:^\$LIBEXECDIR.*:\$LIBEXECDIR=\"${LIBEXECDIR}\";:" \
		-e "s:^\$CONFDIR.*:\$CONFDIR=\"${CONFDIR}\";:" \
		-e "s:^\$HTMLDIR.*:\$HTMLDIR=\"${HTMLDIR}\";:" \
		-e "s:^\$DOCDIR.*:\$DOCDIR=\"${DOCDIR}\";:" \
		-e "s:^# \$PIDDIR=.*:\$PIDDIR=\"${PIDDIR}\";:" \
		-e "s:^\$PREFIX.*:\$PREFIX=\"${PREFIX}\";:" \
		-e "s:^# \$COMMSOCKET.*:\$COMMSOCKET=\"${COMMSOCKET}\";:" \
		-e "s:^\$USER.*:\$USER=\"${USER}\";:" \
		-e "s:^\$WWWUSER.*:\$WWWUSER=\"${WWWUSER}\";:" \
		-e "s:^\$WWWGROUP.*:\$WWWGROUP=\"${WWWGROUP}\";:" \
		-e "s:^[ \t]*'upstream1'.*:#\t'netflow' => { 'port' => '9995', 'col' => '#0000ff' },:" \
		-e "/^[ \t]*'peer1'/d" \
		-e "/^[ \t]*'peer2'/d" \
		-i etc/nfsen-dist.conf
}

src_install() {
	webapp_src_preinst

	keepdir \
		/etc/${PN} \
		/var/lib/${PN}/plugins \
		/var/lib/${PN}/profiles-data/live \
		/var/lib/${PN}/profiles-stat/live \
		/var/lib/${PN}/var/filters \
		/var/lib/${PN}/var/fmt

	local CURRENT_TIME=$(date +%s)
	sed -e "s:%%CURRENT_TIME%%:${CURRENT_TIME}:" "${FILESDIR}"/profile.dat > "${T}"/profile.dat
	insinto /var/lib/"${PN}"/profiles-stat/live
	doins "${T}"/profile.dat

	insinto "${VENDOR_LIB}"/"${PN}"
	doins -r libexec/*

	insinto /etc/"${PN}"
	newins etc/nfsen-dist.conf "${PN}".conf

	dobin bin/nfsen bin/nfsend

	newinitd "${FILESDIR}"/"${PN}".initd nfsen

	doenvd "${FILESDIR}"/50nfsen

	dodoc ChangeLog README README.plugins

	cp -R html/* "${D}"/"${MY_HTDOCSDIR}"
	cp "${FILESDIR}"/conf.php "${D}"/"${MY_HTDOCSDIR}"
	webapp_postinst_txt en "${FILESDIR}"/postinstall-en.txt
	webapp_src_install

	fowners -R ${PN}:${PN} /var/lib/${PN}
}

pkg_postinst() {
	elog "Define your Netflow sources in /etc/${PN}/nfsen.conf. After that, run"
	elog "/usr/bin/nfsen reconfig"
	webapp_pkg_postinst
}
