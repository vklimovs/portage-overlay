# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

WEBAPP_MANUAL_SLOT="yes"

inherit systemd webapp

MY_PN="BackupPC"
MY_P="${MY_PN}-${PV}"

DESCRIPTION="High-performance backups to a server's disk"
HOMEPAGE="https://backuppc.github.io/backuppc/"
SRC_URI="https://github.com/${PN}/${PN}/releases/download/${PV}/${MY_P}.tar.gz"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE="rss samba rrdtool systemd"

DEPEND=">=dev-perl/BackupPC-XS-0.62
	dev-lang/perl
	dev-perl/Archive-Zip
	dev-perl/CGI
	dev-perl/File-Listing
	dev-perl/File-RsyncP
	dev-perl/Time-ParseDate"

RDEPEND="${DEPEND}
	>=net-misc/rsync-bpc-3.1.2.2
	rrdtool? ( net-analyzer/rrdtool[graph] )
	rss? ( dev-perl/XML-RSS )
	samba? ( net-fs/samba )
	acct-group/backuppc
	acct-user/backuppc
	app-arch/par2cmdline
	net-misc/rsync
	virtual/httpd-cgi
	virtual/mta"

S=${WORKDIR}/${MY_P}

set_config_option() {
	# Examples of things this needs to edit:
	# $Conf{HardLinkMax} = 31999;
	# $Conf{PerlModuleLoad} = undef;
	# $Conf{ServerInitdPath}     = '';
	sed -r -e "s:^(\\\$Conf\{$1\}\s+=\s)(.*)(;.*)$:\1'$2'\3:" \
		-i conf/config.pl
}

pkg_setup() {
	webapp_pkg_setup

	# Avoid double slashes
	CGIDIR=${MY_CGIBINDIR/\/\///}
	IMAGEDIR="${MY_HTDOCSDIR/\/\///}"

	CONFDIR="/etc/${PN}"
	LOGDIR="/var/log/${PN}"
	RUNDIR="/run/${PN}"
	TOPDIR="/var/lib/${PN}"
	INSTALLDIR="/usr"
	IMAGEDIRURL="/${PN}"
}

src_prepare() {
	default

	find . -type f -exec sed -i "s:__CGIDIR__:${CGIDIR}:g" {} \;
	find . -type f -exec sed -i "s:__CONFDIR__:${CONFDIR}:g" {} \;
	find . -type f -exec sed -i "s:__IMAGEDIR__:${IMAGEDIR}:g" {} \;
	find . -type f -exec sed -i "s:__IMAGEDIRURL__:${IMAGEDIRURL}:g" {} \;
	find . -type f -exec sed -i "s:__INSTALLDIR__:${INSTALLDIR}:g" {} \;
	find . -type f -exec sed -i "s:__LOGDIR__:${LOGDIR}:g" {} \;
	find . -type f -exec sed -i "s:__RUNDIR__:${RUNDIR}:g" {} \;
	find . -type f -exec sed -i "s:__TOPDIR__:${TOPDIR}:g" {} \;
	find . -type f -exec sed -i "s:__BACKUPPCUSER__:backuppc:g" {} \;

	sed "s:my \$useFHS = 0;:my \$useFHS = 1;:" -i lib/BackupPC/Lib.pm
	sed "s:/share/doc/BackupPC/BackupPC.html:/share/doc/${PF}/BackupPC.html:" \
		-i lib/BackupPC/CGI/View.pm

	set_config_option BackupPCUser backuppc

	set_config_option TopDir "${TOPDIR}"
	set_config_option ConfDir "${CONFDIR}"
	set_config_option LogDir "${LOGDIR}"
	set_config_option RunDir "${RUNDIR}"
	set_config_option InstallDir "${INSTALLDIR}"
	set_config_option CgiDir "${CGIDIR}"
	set_config_option CgiImageDirURL "${IMAGEDIRURL}"

	set_config_option RsyncBackupPCPath /usr/bin/rsync_bpc
	set_config_option TarClientPath /bin/tar
	set_config_option RsyncClientPath /usr/bin/rsync
	set_config_option PingPath /bin/ping
	set_config_option Ping6Path /bin/ping6
	set_config_option DfPath /bin/df
	set_config_option SshPath /usr/bin/ssh
	set_config_option SendmailPath /usr/sbin/sendmail
	set_config_option SplitPath /usr/bin/split
	set_config_option ParPath /usr/bin/par2
	set_config_option CatPath /bin/cat
	set_config_option GzipPath /bin/gzip
	set_config_option Bzip2Path /bin/bzip2

	if use samba; then
		set_config_option SmbClientPath /usr/bin/smbclient
		set_config_option NmbLookupPath /usr/bin/nmblookup
	fi

	use rrdtool && set_config_option RrdToolPath /usr/bin/rrdtool
}

src_compile() {
	pod2man doc/BackupPC.pod backuppc.8
}

src_install() {
	webapp_src_preinst

	insinto "${CONFDIR}"
	doins conf/config.pl conf/hosts

	dobin bin/*

	insinto /usr/lib/
	doins -r lib/*

	dodoc doc/BackupPC.html ChangeLog README.md
	doman backuppc.8

	exeinto "${CGIDIR}"
	doexe cgi-bin/BackupPC_Admin

	insinto "${IMAGEDIR}"
	doins images/* conf/*.js conf/*.css

	keepdir "${LOGDIR}" "${TOPDIR}"/{pool,pc,cpool}

	newinitd "${FILESDIR}"/backuppc.initd backuppc
	newconfd "${FILESDIR}"/backuppc.confd backuppc

	systemd_dounit systemd/src/backuppc.service

	webapp_src_install

	fowners -R backuppc:backuppc "${CONFDIR}" "${LOGDIR}" "${TOPDIR}"
}

pkg_postinst() {
	elog "BackupPC has been installed, but a few more things are required"
	elog "to start using it"
	elog
	elog "- Read the documentation in /usr/share/doc/${PF}/BackupPC.html."
	elog "  Please pay special attention to the security section."
	elog
	elog "- Check the config in ${CONFDIR}/config.pl and make sure to set"
	elog "  CgiAdminUsers and/or CgiAdminUserGroup."
	elog
	elog "- BackupPC consists of a daemon and a CGI web GUI."
	elog
	elog "- You can launch BackupPC daemon by running:"
	elog
	elog "    # /etc/init.d/backuppc start"
	elog
	elog "- The init script uses settings from ${CONFDIR}/config.pl."
	elog
	elog "- To enable the web GUI:"
	elog "    - Install web parts of BackupPC using webapp-config."
	elog "	  - Set up a web server of your choise to run BackupPC_Admin"
	elog "      via CGI."
	elog "    - Set up a web server to serve static assets. BackupPC expects"
	elog "      static assets on ${IMAGEDIRURL} path."
	elog "    - Set up a web server to set REMOTE_USER and SCRIPT_NAME CGI"
	elog "      environment variables, BackupPC needs both to work."

	webapp_pkg_postinst
}
