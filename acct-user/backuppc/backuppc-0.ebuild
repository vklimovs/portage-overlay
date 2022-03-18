# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

DESCRIPTION="user for backuppc"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( backuppc )
ACCT_USER_HOME="/var/lib/backuppc"

acct-user_add_deps
