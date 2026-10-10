# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/openpgp-keys/elastic.asc

inherit systemd verify-sig

DESCRIPTION="Free and Open, Distributed, RESTful Search Engine"
HOMEPAGE="https://www.elastic.co/elasticsearch/"
MY_URI="https://artifacts.elastic.co/downloads/${PN}"
SRC_URI="
	${MY_URI}/${P}-linux-x86_64.tar.gz
	verify-sig? ( ${MY_URI}/${P}-linux-x86_64.tar.gz.asc )
"

LICENSE="Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD BSD-2 Boost-1.0 CC0-1.0
	Elastic-2.0 EPL-2.0 GPL-2-with-classpath-exception GPL-3+
	gcc-runtime-library-exception-3.1 icu ISSL MIT MPL-1.1 MPL-2.0 public-domain
	ZLIB"
SLOT="0"
KEYWORDS="-* ~amd64"

# JDK rather than JRE, bug #950962
RDEPEND="
	acct-group/elasticsearch
	acct-user/elasticsearch
	dev-java/java-config:2
	virtual/jdk:21
	virtual/zlib
"
BDEPEND="
	acct-group/elasticsearch
	acct-user/elasticsearch
	verify-sig? ( sec-keys/openpgp-keys-elastic )
"

QA_PREBUILT="
	usr/share/${PN}/lib/platform/linux-x64/*
	usr/share/${PN}/lib/tools/server-launcher/server-launcher
	usr/share/${PN}/modules/x-pack-ml/platform/linux-x86_64/*
"

PATCHES=( "${FILESDIR}"/${P}-java-home.patch )

src_prepare() {
	default

	rm -r jdk logs plugins || die

	sed -i "s|^#path.logs: .*|path.logs: ${EPREFIX}/var/log/${PN}|" \
		config/elasticsearch.yml || die
	sed -i \
		"s|ES_PATH_CONF=\"\$ES_HOME\"/config|ES_PATH_CONF=\"${EPREFIX}/etc/${PN}\"|" \
		bin/elasticsearch-env || die
}

src_install() {
	diropts -g ${PN} -m 2750
	insopts -g ${PN} -m 0660
	insinto /etc/${PN}
	doins -r config/.
	keepdir /etc/${PN}/jvm.options.d
	rm -r config || die
	diropts -m 0755
	insopts -m 0644

	insinto /usr/share/${PN}
	doins -r .

	exeinto /usr/share/${PN}/bin
	doexe "${FILESDIR}"/{elasticsearch-keystore-prepare,systemd-entrypoint}

	fperms -R +x \
		/usr/share/${PN}/bin \
		/usr/share/${PN}/modules/x-pack-ml/platform/linux-x86_64/bin
	fperms +x /usr/share/${PN}/lib/tools/server-launcher/server-launcher

	insinto /usr/lib/sysctl.d
	newins "${FILESDIR}"/${PN}.sysctl ${PN}.conf

	newconfd "${FILESDIR}"/${PN}.confd ${PN}
	newinitd "${FILESDIR}"/${PN}.initd ${PN}

	systemd_dounit "${FILESDIR}"/${PN}.service
	systemd_install_serviced "${FILESDIR}"/${PN}.service.conf

	diropts -o ${PN} -g ${PN} -m 0750
	keepdir /var/{lib,log}/${PN}
}

pkg_postinst() {
	# The plugin manager needs this directory, and the server refuses to start
	# with keepdir's placeholder inside it.
	mkdir -p "${EROOT}"/usr/share/${PN}/plugins || die
	# Was the service user's home before acct-user/elasticsearch-0-r4, and
	# merging does not reset ownership of an existing directory.
	chown root:root "${EROOT}"/usr/share/${PN} || die

	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog "Security is enabled by default. To generate TLS certificates and a"
		elog "password for the elastic user, as upstream's packages do, run:"
		elog "  emerge --config ${CATEGORY}/${PN}"
		elog
		elog "systemd: apply vm.max_map_count with 'sysctl --system' or a reboot."
		elog
		elog "OpenRC: further instances are created by symlinking the init script,"
		elog "e.g. /etc/init.d/${PN}.foo, configured from /etc/${PN}/foo."
	fi
}

pkg_config() {
	local -x ES_PATH_CONF="${EROOT}/etc/${PN}"
	local -x CLI_LIBS="modules/x-pack-core,modules/x-pack-security"
	CLI_LIBS+=",lib/tools/security-cli"
	local cli="${EROOT}/usr/share/${PN}/bin/elasticsearch-cli" ret

	CLI_NAME=auto-configure-node "${cli}" <<< ""
	ret=$?
	if [[ ${ret} -eq 80 ]]; then
		einfo "Security is already configured, nothing to do."
		return
	fi
	[[ ${ret} -eq 0 ]] || die "Security auto-configuration failed"

	chown root:${PN} \
		"${ES_PATH_CONF}"/certs/{http.p12,http_ca.crt,transport.p12} || die

	einfo "TLS is enabled for HTTP and transport, and HTTP now listens on all"
	einfo "interfaces. See ${ES_PATH_CONF}/elasticsearch.yml."
	einfo "The password for the elastic user is:"
	CLI_NAME=auto-config-gen-passwd "${cli}" || die
}
