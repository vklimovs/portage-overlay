# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module systemd

# Upstream tags rarely; ${PV}'s _pYYYYMMDD is this commit's date.
COMMIT="9d1c281d8d7e5473ae5120c0282978778d8a865e"

DESCRIPTION="Private certificate authority and ACME server"
HOMEPAGE="https://github.com/smallstep/certificates"

# To generate the vendor tarball:
#   tar -xf ${P}.tar.gz
#   cd certificates-*/
#   go mod vendor
#   cd ..
#   tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
#       -cf - certificates-*/vendor | xz -9e >"${P}-vendor.tar.xz"
SRC_URI="
	https://github.com/smallstep/certificates/archive/${COMMIT}.tar.gz
		-> ${P}.tar.gz
	https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
"
S="${WORKDIR}/certificates-${COMMIT}"

# step-ca itself
LICENSE="Apache-2.0"
# Vendored package licenses
LICENSE+=" BSD BSD-2 MIT MPL-2.0 pkcs11? ( OASIS-Open )"
SLOT="0"
KEYWORDS="~amd64"
IUSE="pcsc-lite pkcs11"

DEPEND="pcsc-lite? ( sys-apps/pcsc-lite )"
RDEPEND="
	${DEPEND}
	acct-group/step
	acct-user/step
"
BDEPEND="
	>=dev-lang/go-1.26.0
	pcsc-lite? ( virtual/pkgconfig )
"

src_configure() {
	GOFLAGS+=" -tags=$(usev !pcsc-lite noyubikey),$(usev !pkcs11 nopkcs11)"
}

src_compile() {
	# Unset, BuildTime makes `step-ca version` print the current time.
	ego build -trimpath \
		-ldflags "-X main.Version=${PV} -X main.BuildTime=${PV##*_p}" \
		./cmd/step-ca
}

src_test() {
	# Fetches https://smallstep.com.
	ego test -skip 'Test_newHTTPClient/SystemCertPool' ./...
}

src_install() {
	dobin step-ca
	einstalldocs
	newinitd "${FILESDIR}/${PN}.initd" "${PN}"
	newconfd "${FILESDIR}/${PN}.confd" "${PN}"
	systemd_dounit systemd/step-ca.service
}
