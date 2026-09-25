# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module

DESCRIPTION="High-performance pipeline to capture, transform and ship DNS telemetry"
HOMEPAGE="https://dmachard.github.io/DNS-collector/ https://github.com/dmachard/DNS-collector"

# To generate the vendor tarball:
#   tar -xf ${P}.tar.gz
#   cd DNS-collector-${PV}
#   go mod vendor
#   cd ..
#   tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
#       -cf - DNS-collector-${PV}/vendor | xz -9e >"${P}-vendor.tar.xz"
SRC_URI="
	https://github.com/dmachard/DNS-collector/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
"
S="${WORKDIR}/DNS-collector-${PV}"

# dnscollector itself
LICENSE="MIT"
# Vendored package licenses
LICENSE+=" AGPL-3 Apache-2.0 BSD BSD-2 EPL-2.0 ISC MPL-2.0"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="
	acct-group/${PN}
	acct-user/${PN}
"
# runuser, which the init script validates the config with, needs util-linux[pam].
RDEPEND="
	${DEPEND}
	sys-apps/util-linux[pam]
"
BDEPEND=">=dev-lang/go-1.26.5"

DOCS=( README.md docs/configuration.md docs/formats.md docs/pipelines.md )

src_compile() {
	ego build \
		-mod=vendor \
		-trimpath \
		-ldflags "-X github.com/prometheus/common/version.Version=${PV}" \
		-o "${PN}" .
}

src_test() {
	# ./tests holds no unit test: its one case clones the previous release
	# from git and diffs the two binaries.
	ego test -mod=vendor -skip TestCompare_VersionN1 ./...
}

src_install() {
	dobin "${PN}"
	einstalldocs

	docinto examples
	dodoc docs/examples/*.yml

	# Pipelines carry broker, database and TLS credentials.
	insinto /etc/${PN}
	doins config.yml
	fowners root:${PN} /etc/${PN} /etc/${PN}/config.yml
	fperms 0750 /etc/${PN}
	fperms 0640 /etc/${PN}/config.yml

	newinitd "${FILESDIR}/${PN}.initd" "${PN}"
	newconfd "${FILESDIR}/${PN}.confd" "${PN}"

	insinto /etc/logrotate.d
	newins "${FILESDIR}/${PN}.logrotate" "${PN}"

	keepdir /var/log/${PN}
	fowners ${PN}:${PN} /var/log/${PN}
	fperms 0750 /var/log/${PN}
}
