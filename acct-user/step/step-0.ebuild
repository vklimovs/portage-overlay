# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

DESCRIPTION="user for step-ca"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( step )
# The STEPPATH that upstream's step-ca.service and the OpenRC conf.d both set.
ACCT_USER_HOME=/etc/step-ca
ACCT_USER_HOME_OWNER=step:step

acct-user_add_deps
