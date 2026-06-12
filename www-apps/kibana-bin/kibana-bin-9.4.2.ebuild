# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/openpgp-keys/elastic.asc

inherit systemd verify-sig

MY_PN="${PN%-bin}"
MY_P=${MY_PN}-${PV}

DESCRIPTION="Analytics and search dashboard for Elasticsearch"
HOMEPAGE="https://www.elastic.co/kibana"
SRC_URI="
	https://artifacts.elastic.co/downloads/${MY_PN}/${MY_P}-linux-x86_64.tar.gz
	verify-sig? ( https://artifacts.elastic.co/downloads/${MY_PN}/${MY_P}-linux-x86_64.tar.gz.asc )
"
S="${WORKDIR}/${MY_P}"

LICENSE="Apache-2.0 Artistic-2 BlueOak-1.0.0 BSD BSD-2 CC0-1.0 CC-BY-SA-4.0 Elastic-2.0 icu ISC MIT MPL-2.0 OFL-1.1 public-domain PYTHON Unlicense WTFPL-2 ZLIB"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="mirror strip"

# Upstream pins an exact nodejs version (strict === check) that rarely
# matches what's in ::gentoo, so we depend on the closest available version;
# src_prepare injects the upstream-provided
# UNSAFE_DISABLE_NODE_VERSION_VALIDATION env var into all launcher scripts
# so the check is bypassed at runtime.
RDEPEND="
	acct-group/kibana
	acct-user/kibana
	dev-libs/expat
	dev-libs/nspr
	dev-libs/nss
	~net-libs/nodejs-24.14.0[inspector,ssl]
	sys-libs/glibc
"
BDEPEND="verify-sig? ( sec-keys/openpgp-keys-elastic )"

src_prepare() {
	default

	rm -r data node plugins || die

	local script
	for script in bin/*; do
		grep -q '^NODE="' "${script}" \
			|| die "${script} no longer contains a NODE= assignment"
		sed -i \
			-e 's@^NODE=.*@NODE="/usr/bin/node"@' \
			-e '\@^NODE="@a export UNSAFE_DISABLE_NODE_VERSION_VALIDATION=1' \
			"${script}" || die
	done
}

src_install() {
	insinto /etc/${MY_PN}
	doins -r config/.
	rm -r config || die

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/${MY_PN}.logrotate ${MY_PN}

	newconfd "${FILESDIR}"/${MY_PN}.confd ${MY_PN}
	newinitd "${FILESDIR}"/${MY_PN}.initd ${MY_PN}
	systemd_dounit "${FILESDIR}"/${MY_PN}.service

	insinto /opt/${MY_PN}
	doins -r .

	fperms -R +x /opt/${MY_PN}/bin

	diropts -m 0750 -o ${MY_PN} -g ${MY_PN}
	keepdir /var/lib/${MY_PN}/plugins
	keepdir /var/log/${MY_PN}

	dosym ../../var/lib/${MY_PN}/plugins /opt/${MY_PN}/plugins
	dosym ../../var/lib/${MY_PN} /opt/${MY_PN}/data
}
