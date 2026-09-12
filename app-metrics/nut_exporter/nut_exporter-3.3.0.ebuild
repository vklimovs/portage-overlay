# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module

DESCRIPTION="Prometheus exporter for Network UPS Tools"
HOMEPAGE="https://github.com/DRuggeri/nut_exporter"

# To generate the vendor tarball:
#   tar -xf ${P}.tar.gz
#   cd ${P}
#   go mod vendor
#   cd ..
#   tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
#       -cf - ${P}/vendor | xz -9e >"${P}-vendor.tar.xz"
SRC_URI="
	https://github.com/DRuggeri/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
"

# nut_exporter itself
LICENSE="Apache-2.0"
# Vendored package licenses
LICENSE+=" BSD MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	acct-group/${PN}
	acct-user/${PN}
"
DEPEND="${RDEPEND}"

DOCS=( README.md )

src_compile() {
	ego build \
		-mod=vendor \
		-trimpath \
		-ldflags "-X main.Version=${PV}" \
		-o "${PN}" .
}

src_test() {
	# The test execs the binary by bare name, so it has to be found on PATH.
	local -x PATH="${S}:${PATH}"
	ego test -mod=vendor ./...
}

src_install() {
	dobin "${PN}"
	einstalldocs

	docinto dashboard
	dodoc dashboard/dashboard.json

	newinitd "${FILESDIR}/${PN}.initd" "${PN}"
	newconfd "${FILESDIR}/${PN}.confd" "${PN}"

	insinto /etc/logrotate.d
	newins "${FILESDIR}/${PN}.logrotate" "${PN}"

	keepdir /var/log/${PN}
	fowners ${PN}:${PN} /var/log/${PN}
}
