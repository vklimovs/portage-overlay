# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

WEBAPP_MANUAL_SLOT="yes"

inherit systemd webapp

DESCRIPTION="High-performance backups to a server's disk"
HOMEPAGE="https://backuppc.github.io/backuppc/"
SRC_URI="https://github.com/${PN}/${PN}/releases/download/${PV}/${P}.tar.gz"
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
	acct-group/backuppc
	acct-user/backuppc
	rrdtool? ( net-analyzer/rrdtool[graph] )
	rss? ( dev-perl/XML-RSS )
	samba? ( net-fs/samba )
	>=net-misc/rsync-bpc-3.1.2.2
	net-misc/rsync
	virtual/httpd-cgi
	virtual/mta"

src_compile() {
	pod2man doc/"${PN}".pod backuppc.8
}

src_install() {
	webapp_src_preinst

	insinto /etc/"${PN}"
	doins conf/config.pl conf/hosts

	dobin bin/*

	insinto /usr/lib/
	doins -r lib/"${PN}"

	dodoc doc/"${PN}".html ChangeLog README.md
	doman backuppc.8

	exeinto "${MY_CGIBINDIR}"
	doexe cgi-bin/"${PN}"_Admin

	insinto "${MY_HTDOCSDIR}"
	doins images/*
	doins conf/*.js conf/*.css

	keepdir "/var/lib/${PN}"/{pool,pc,cpool}
	fowners -R backuppc:backuppc "/var/lib/${PN}"

	keepdir "/var/log/${PN}"
	fowners -R backuppc:backuppc "/var/log/${PN}"

	#if ! use systemd; then
	#	newinitd systemd/src/init.d/gentoo-backuppc backuppc
	#	newconfd systemd/src/init.d/gentoo-backuppc.conf backuppc
	#fi
	#
	#if use systemd; then
	#	systemd_dounit systemd/src/"${PN}".service
	#fi

	webapp_src_install
}