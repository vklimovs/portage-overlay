# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools linux-info

DESCRIPTION="Static multicast routing for UNIX"
HOMEPAGE="https://troglobit.com/projects/smcroute"
SRC_URI="https://github.com/troglobit/smcroute/archive/${PV}.tar.gz ->
	${P}.tar.gz"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="caps mrdisc systemd"

RDEPEND="acct-group/smcroute
	acct-user/smcroute
	caps? ( sys-libs/libcap )"

DEPEND="${RDEPEND}"

CONFIG_CHECK="~IP_MULTICAST ~IP_MROUTE ~IP_PIMSM_V1 ~IP_PIMSM_V2
	~IP_MROUTE_MULTIPLE_TABLES ~IPV6_MROUTE_MULTIPLE_TABLES"

pkg_setup() {
	linux-info_pkg_setup
}

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	econf \
		--localstatedir="${EPREFIX}"/var \
		$(use_enable mrdisc) \
		$(use_with systemd) \
		$(use_with caps libcap)
}

src_install() {
	default

	#remove compatibility wrapper
	rm -f "${ED}"/usr/sbin/smcroute

	insinto /etc
	newins "${S}"/smcroute.conf smcroute.conf.example
	newinitd "${FILESDIR}/${PN}.initd" smcrouted
}
