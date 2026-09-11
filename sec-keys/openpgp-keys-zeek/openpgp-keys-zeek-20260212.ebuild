# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

SEC_KEYS_VALIDPGPKEYS=(
	'962FD2187ED5A1DD82FC478A33F15EAEF8CB8019:zeek:openpgp'
)

inherit sec-keys

DESCRIPTION="OpenPGP key used by the Zeek project to sign release tarballs"
HOMEPAGE="https://zeek.org/"

KEYWORDS="~amd64"
