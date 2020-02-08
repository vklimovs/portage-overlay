# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit acct-user

DESCRIPTION="user for nfsen"
ACCT_USER_ID=469
ACCT_USER_GROUPS=( nfsen )
ACCT_USER_HOME="/var/lib/nfsen"

acct-user_add_deps
