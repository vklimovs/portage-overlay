# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit acct-user

DESCRIPTION="user for influxdb"
ACCT_USER_ID=468
ACCT_USER_GROUPS=( influxdb )
ACCT_USER_HOME="/var/lib/influxdb"

acct-user_add_deps
