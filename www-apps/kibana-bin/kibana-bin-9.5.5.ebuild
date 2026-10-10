# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/openpgp-keys/elastic.asc

inherit systemd verify-sig

MY_PN="${PN%-bin}"
MY_P=${MY_PN}-${PV}

DESCRIPTION="Analytics and search dashboard for Elasticsearch"
HOMEPAGE="https://www.elastic.co/kibana"
MY_URI="https://artifacts.elastic.co/downloads/${MY_PN}"
SRC_URI="
	${MY_URI}/${MY_P}-linux-x86_64.tar.gz
	verify-sig? ( ${MY_URI}/${MY_P}-linux-x86_64.tar.gz.asc )
"
S="${WORKDIR}/${MY_P}"

# Elastic-2.0 and node_modules, plus the screenshotting plugin's bundled
# Chromium, licensed as www-client/chromium
LICENSE="0BSD Apache-2.0 Apache-2.0-with-LLVM-exceptions Base64 BlueOak-1.0.0
	Boost-1.0 BSD BSD-2 CC-BY-3.0 CC-BY-4.0 CC0-1.0 Clear-BSD Elastic-2.0 FFT2D
	FTL IJG ISC LGPL-2 LGPL-2.1 LGPL-3 LGPL-3+ libtiff MIT MIT-0 MPL-1.1 MPL-2.0
	Ms-PL OFL-1.1 openssl PSF-2 public-domain SGI-B-2.0 SSLeay SunSoft
	Unicode-3.0 Unicode-DFS-2015 Unlicense UoI-NCSA ZLIB"
SLOT="0"
KEYWORDS="-* ~amd64"

# Kibana refuses to start on any other Node.js version.
RDEPEND="
	acct-group/kibana
	acct-user/kibana
	dev-libs/expat
	dev-libs/nspr
	dev-libs/nss
	~net-libs/nodejs-24.21.0[inspector,ssl]
"
BDEPEND="
	acct-group/kibana
	acct-user/kibana
	verify-sig? ( sec-keys/openpgp-keys-elastic )
"

QA_PREBUILT="opt/${MY_PN}/*"

src_prepare() {
	default

	rm -r data node plugins || die

	local script
	for script in bin/*; do
		grep -q '^NODE="' "${script}" || die
		sed -i "s|^NODE=.*|NODE=\"${EPREFIX}/usr/bin/node\"|" "${script}" || die
	done
}

src_install() {
	diropts -g ${MY_PN} -m 2750
	insopts -g ${MY_PN} -m 0660
	insinto /etc/${MY_PN}
	doins -r config/.
	rm -r config || die
	diropts -m 0755
	insopts -m 0644

	insinto /opt/${MY_PN}
	doins -r .

	fperms -R +x /opt/${MY_PN}/bin
	local chromium=node_modules/@kbn/screenshotting-plugin/chromium
	fperms +x /opt/${MY_PN}/${chromium}/headless_shell-linux_x64/headless_shell

	dosym -r /etc/${MY_PN} /opt/${MY_PN}/config
	dosym -r /var/lib/${MY_PN} /opt/${MY_PN}/data
	dosym -r /var/lib/${MY_PN}/plugins /opt/${MY_PN}/plugins

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/${MY_PN}.logrotate ${MY_PN}

	newconfd "${FILESDIR}"/${MY_PN}.confd ${MY_PN}
	newinitd "${FILESDIR}"/${MY_PN}.initd ${MY_PN}
	systemd_dounit "${FILESDIR}"/${MY_PN}.service

	diropts -o ${MY_PN} -g ${MY_PN} -m 0750
	keepdir /var/lib/${MY_PN}/plugins /var/log/${MY_PN}
}

pkg_postinst() {
	# Merging keeps the ownership of an existing directory, and earlier
	# versions left this one world-readable while kibana.yml holds credentials.
	chown root:${MY_PN} "${EROOT}"/etc/${MY_PN} || die
	chmod 2750 "${EROOT}"/etc/${MY_PN} || die
}
