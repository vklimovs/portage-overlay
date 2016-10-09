EAPI=5

inherit perl-module user webapp

MY_P=${P/_/}
DESCRIPTION="nfsen is a graphical web based front end for the nfdump netflow tools"
HOMEPAGE="http://nfsen.sourceforge.net/"
SRC_URI="http://sourceforge.net/projects/nfsen/files/stable/${MY_P}/${MY_P}.tar.gz"

LICENSE="BSD"
KEYWORDS="~x86 ~amd64"
IUSE=""

RDEPEND="dev-perl/MailTools
	dev-perl/Socket6
	>=net-analyzer/nfdump-1.6.5[nfprofile]
	>dev-lang/php-4.1[sockets]
	net-analyzer/rrdtool[graph,perl]"

S=${WORKDIR}/${MY_P}

pkg_setup() {
	webapp_pkg_setup
	enewgroup ${PN}
	enewuser ${PN} -1 -1 -1 ${PN}
}

src_prepare() {
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

	epatch "${FILESDIR}"/nfsen-1.3.6p1-profileadmin.php.patch
	epatch "${FILESDIR}"/nfsen-1.3.6p1-rrd-version.patch
	epatch "${FILESDIR}"/nfsen-1.3.6p1-socket6-inet_pton.patch
}

src_install() {
	webapp_src_preinst

	dodoc ChangeLog README README.plugins

	insinto ${VENDOR_LIB}/${PN}
	doins -r libexec/*

	dobin bin/nfsen bin/nfsend

	doinitd ${FILESDIR}/nfsen

	dodir \
		/etc/${PN} \
		/var/lib/${PN}/plugins \
		/var/lib/${PN}/profiles-data/live \
		/var/lib/${PN}/profiles-stat/live \
		/var/lib/${PN}/var/filters \
		/var/lib/${PN}/var/fmt


	insinto /etc/${PN}
	newins etc/nfsen-dist.conf ${PN}.conf

	insinto /var/lib/${PN}/profiles-stat/live
	doins ${FILESDIR}/profile.dat

	cp -R html/* ${D}/${MY_HTDOCSDIR}
	cp ${FILESDIR}/conf.php ${D}/${MY_HTDOCSDIR}
	webapp_postinst_txt en ${FILESDIR}/postinstall-en.txt
	webapp_src_install

	fowners -R ${PN}:${PN} /var/lib/${PN}
}

pkg_postinst() {
	elog "Define your Netflow sources in /etc/${PN}/nfsen.conf. After that, run"
	elog "/usr/bin/nfsen reconfig"
	webapp_pkg_postinst
}
