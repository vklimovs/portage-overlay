# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module systemd

DESCRIPTION="Lightweight log shipper for Logstash and Elasticsearch"
HOMEPAGE="
	https://www.elastic.co/beats/filebeat
	https://github.com/elastic/beats
"

# To generate the vendor tarball:
#   tar -xf ${P}.tar.gz
#   cd beats-${PV}
#   rm -r x-pack
#   go mod vendor
#   cd ..
#   tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
#       -cf - beats-${PV}/vendor | xz -9e >"${P}-vendor.tar.xz"
SRC_URI="
	https://github.com/elastic/beats/archive/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
"
S="${WORKDIR}/beats-${PV}"

LICENSE="Apache-2.0 BSD BSD-2 ISC MIT MPL-2.0"
SLOT="0"
KEYWORDS="~amd64"
# Pin comes from .go-version at the beats tag, not go.mod.
BDEPEND=">=dev-lang/go-1.26.8"

src_prepare() {
	default
	rm -r x-pack || die
}

src_compile() {
	ego build -mod=vendor -trimpath -o filebeat/filebeat ./filebeat
}

src_test() {
	# The journald input tests run journalctl, which only systemd systems have.
	# The udp input's TestInput is timing-dependent and fails about one run in
	# ten.
	ego test -mod=vendor $(ego list -mod=vendor ./filebeat/... \
		| grep -v -e '/filebeat/input/journald$' -e '/filebeat/input/net/udp$' \
		|| die)
}

src_install() {
	exeinto /usr/share/${PN}/bin
	doexe filebeat/filebeat
	newbin "${FILESDIR}"/${PN}.sh ${PN}

	find filebeat/module \( -name _meta -o -name test -o -name fields.go \) \
		-prune -exec rm -r {} + || die
	insinto /usr/share/${PN}
	doins -r filebeat/module

	insinto /etc/${PN}
	doins filebeat/${PN}.yml
	doins -r filebeat/modules.d
	fperms 0600 /etc/${PN}/${PN}.yml

	dodoc filebeat/${PN}.reference.yml

	newconfd "${FILESDIR}"/${PN}.confd ${PN}
	newinitd "${FILESDIR}"/${PN}.initd ${PN}
	systemd_dounit "${FILESDIR}"/${PN}.service

	diropts -m 0750
	keepdir /var/{lib,log}/${PN}
}

pkg_postinst() {
	if [[ -d ${EROOT}/var/lib/${PN}/data/registry ]]; then
		ewarn "${EROOT}/var/lib/${PN}/data/registry is from an earlier OpenRC setup"
		ewarn "that used --path.home=/var/lib/${PN}. The registry is now read from"
		ewarn "${EROOT}/var/lib/${PN}/registry. Move it there before starting ${PN},"
		ewarn "or every input is shipped again from the beginning."
	fi
}
