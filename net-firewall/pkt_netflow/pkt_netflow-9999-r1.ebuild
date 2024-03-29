# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit linux-mod-r1 toolchain-funcs

DESCRIPTION="Standalone kernel netflow module"
HOMEPAGE="https://github.com/aabc/pkt-netflow"
SRC_URI="https://github.com/aabc/pkt-netflow/archive/86208e286e9dc57e46939191a16163a89105f4b4.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"

IUSE="snmp"

RDEPEND="snmp? ( net-analyzer/net-snmp )"

DEPEND="${RDEPEND}
	virtual/linux-sources
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}/${P}-flags.patch"
	"${FILESDIR}/${P}-warn-on-failed-connection.patch"
	"${FILESDIR}/${P}-fix-linux-headers-5.14.patch"
	"${FILESDIR}/${P}-fix-6.4-register_sysctl_paths-removal.patch"
	"${FILESDIR}/${P}-use-explicit-fallthrough-macro.patch"
)

CONFIG_CHECK="~IPV6 ~PROC_FS ~SYSCTL ~VLAN_8021Q"

src_unpack () {
	default
	mv "${WORKDIR}"/*netflow* "${S}" || die
}

src_prepare() {
	default

	# Checking for directory is enough
	sed -i \
		-e 's:-s /etc/snmp/snmpd.conf:-d /etc/snmp:' \
		configure || die
}

do_conf() {
	tc-export CC
	echo ./configure $*
	./configure $* ${EXTRA_ECONF} || die 'configure failed'
}

src_configure() {
	do_conf \
		--disable-dkms \
		--enable-aggregation \
		--enable-direction \
		--enable-macaddress \
		--enable-vlan \
		--kdir="${KV_DIR}" \
		--kver="${KV_FULL}" \
		$(use snmp && echo '--enable-snmp-rules' || echo '--disable-snmp-agent')
}

src_compile() {
	local modlist=( pkt_netflow )
	linux-mod-r1_src_compile
}

src_install() {
	use snmp && emake DESTDIR="${D}" SNMPTGSO="/usr/$(get_libdir)/snmp/dlmod/snmp_netflow.so" sinstall
	linux-mod-r1_src_install
	dodoc README*
}
