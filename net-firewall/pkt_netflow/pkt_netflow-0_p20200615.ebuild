# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-mod-r1 toolchain-funcs

# Upstream has been frozen since 2020-06-15; pin to the last commit rather
# than tracking a live branch that never moves.
COMMIT="86208e286e9dc57e46939191a16163a89105f4b4"

DESCRIPTION="Standalone kernel netflow module"
HOMEPAGE="https://github.com/aabc/pkt-netflow"
SRC_URI="https://github.com/aabc/pkt-netflow/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/pkt-netflow-${COMMIT}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="snmp"

RDEPEND="snmp? ( net-analyzer/net-snmp )"
DEPEND="${RDEPEND}"
BDEPEND="virtual/linux-sources"

PATCHES=(
	"${FILESDIR}/${P}-respect-user-flags.patch"
	"${FILESDIR}/${P}-warn-on-failed-connection.patch"
	"${FILESDIR}/${P}-fix-linux-headers-5.14.patch"
	"${FILESDIR}/${P}-fix-6.2-timer-delete-sync.patch"
	"${FILESDIR}/${P}-fix-6.4-register_sysctl_paths-removal.patch"
	"${FILESDIR}/${P}-fix-6.8-strlcpy-removal.patch"
	"${FILESDIR}/${P}-fix-6.11-const-sysctl-handlers.patch"
	"${FILESDIR}/${P}-fix-6.12-unaligned-header.patch"
	"${FILESDIR}/${P}-use-explicit-fallthrough-macro.patch"
	"${FILESDIR}/${P}-snmp-include-unistd.patch"
)

CONFIG_CHECK="~IPV6 ~PROC_FS ~SYSCTL ~VLAN_8021Q"

src_prepare() {
	default

	# Checking for the directory is enough
	sed -i \
		-e 's:-s /etc/snmp/snmpd.conf:-d /etc/snmp:' \
		configure || die
}

do_conf() {
	tc-export CC
	echo ./configure "$@"
	./configure "$@" ${EXTRA_ECONF} || die
}

src_configure() {
	# this configure script is not based on autotools
	do_conf \
		--disable-dkms \
		--enable-aggregation \
		--enable-direction \
		--enable-macaddress \
		--enable-vlan \
		--kdir="${KV_DIR}" \
		--kver="${KV_FULL}" \
		$(usex snmp --enable-snmp-rules --disable-snmp-agent)
}

src_compile() {
	local modlist=( pkt_netflow )
	linux-mod-r1_src_compile
}

src_install() {
	linux-mod-r1_src_install

	use snmp && emake CC="$(tc-getCC)" DESTDIR="${D}" \
		SNMPTGSO="/usr/$(get_libdir)/snmp/dlmod/snmp_netflow.so" sinstall

	dodoc README*
}
