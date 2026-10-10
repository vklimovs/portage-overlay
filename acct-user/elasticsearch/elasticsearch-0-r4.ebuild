# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

DESCRIPTION="Elasticsearch program user"
ACCT_USER_ID=183
ACCT_USER_GROUPS=( elasticsearch )
acct-user_add_deps
