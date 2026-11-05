# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

DESCRIPTION="user for step-ca"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( step )
# Upstream's STEPPATH for the service; `step ca init` lays the CA out here.
ACCT_USER_HOME=/etc/step-ca
ACCT_USER_HOME_OWNER=step:step

acct-user_add_deps
