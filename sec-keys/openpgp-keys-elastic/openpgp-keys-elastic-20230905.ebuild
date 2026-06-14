# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

SEC_KEYS_VALIDPGPKEYS=(
	'46095ACC8548582C1A2699A9D27D666CD88E42B4:elastic:manual'
)

inherit sec-keys

DESCRIPTION="OpenPGP key used by Elastic to sign release artifacts"
HOMEPAGE="https://www.elastic.co/docs/deploy-manage/deploy/self-managed/installing-elasticsearch"
SRC_URI+="https://artifacts.elastic.co/GPG-KEY-elasticsearch -> elastic-${PV}.gpg"

KEYWORDS="~amd64"
