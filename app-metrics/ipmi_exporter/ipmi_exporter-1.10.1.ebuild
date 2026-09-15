# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module

DESCRIPTION="Prometheus exporter for IPMI baseboard management controllers"
HOMEPAGE="https://github.com/prometheus-community/ipmi_exporter"

# To generate the vendor tarball:
#   tar -xf ${P}.tar.gz
#   cd ${P}
#   go mod vendor
#   cd ..
#   tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
#       -cf - ${P}/vendor | xz -9e >"${P}-vendor.tar.xz"
SRC_URI="
	https://github.com/prometheus-community/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
"

# ipmi_exporter itself
LICENSE="MIT"
# Vendored package licenses
LICENSE+=" Apache-2.0 BSD"
SLOT="0"
KEYWORDS="~amd64"

# The init script runs the exporter as its own user, and FreeIPMI refuses
# to run as anyone but root unless built with this flag.
RDEPEND="
	acct-group/${PN}
	acct-user/${PN}
	sys-libs/freeipmi[without-root]
"
DEPEND="${RDEPEND}"

DOCS=( CHANGELOG.md README.md docs/configuration.md docs/metrics.md
	docs/privileges.md )

src_compile() {
	ego build \
		-mod=vendor \
		-trimpath \
		-ldflags "-X github.com/prometheus/common/version.Version=${PV}" \
		-o "${PN}" .
}

# Displaces the default phase, which would run the upstream Makefile's test
# target and reach for promu and the network.
src_test() {
	ego test -mod=vendor ./...
}

src_install() {
	dobin "${PN}"
	einstalldocs

	newinitd "${FILESDIR}/${PN}.initd" "${PN}"
	newconfd "${FILESDIR}/${PN}.confd" "${PN}"

	insinto /etc/logrotate.d
	newins "${FILESDIR}/${PN}.logrotate" "${PN}"

	keepdir /var/log/${PN}
	fowners ${PN}:${PN} /var/log/${PN}
}
