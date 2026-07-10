# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module systemd

DESCRIPTION="Lightweight log shipper for Logstash and Elasticsearch"
HOMEPAGE="https://www.elastic.co/beats/filebeat https://github.com/elastic/beats"

# To generate the vendor tarball:
#   tar -xf ${P}.tar.gz
#   cd beats-${PV}
#   rm -r x-pack
#   go mod vendor
#   cd ..
#   tar -caf ${P}-vendor.tar.xz beats-${PV}/vendor
SRC_URI="
	https://github.com/elastic/beats/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
"
S="${WORKDIR}/beats-${PV}"

LICENSE="Apache-2.0 BSD BSD-2 CC-BY-3.0 CC0-1.0 EPL-2.0 ISC MIT MPL-2.0 public-domain PYTHON ZLIB"
SLOT="0"
KEYWORDS="~amd64"
BDEPEND=">=dev-lang/go-1.26.4:="

src_prepare() {
	default
	rm -r x-pack || die
}

src_compile() {
	cd filebeat || die
	ego build -mod=vendor -trimpath -buildmode=pie -o filebeat .
}

src_install() {
	dobin filebeat/filebeat
	insinto /etc/${PN}
	doins filebeat/${PN}.yml
	keepdir /var/lib/${PN}
	newinitd "${FILESDIR}/${PN}.initd" ${PN}
	systemd_dounit "${FILESDIR}/${PN}.service"
}
