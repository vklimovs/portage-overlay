# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7
DIST_AUTHOR=CBARRATT
DIST_VERSION=0.62

inherit perl-module

DESCRIPTION="BackupPC::XS implements various BackupPC functions in a
	perl-callable module."
HOMEPAGE="https://github.com/backuppc/backuppc-xs/"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86"

RDEPEND="net-misc/rsync-bpc"
DEPEND="${RDEPEND}
	dev-perl/Module-Build"

src_test() {
	perl-module_src_test
}
