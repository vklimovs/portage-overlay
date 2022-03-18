# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{8,9,10} )
inherit cmake python-single-r1

DESCRIPTION="The Zeek Network Security Monitor"
HOMEPAGE="https://www.zeek.org"
SRC_URI="https://download.zeek.org/${P}.tar.gz"
LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="curl debug geoip2 ipsumdump ipv6 jemalloc kerberos +python sendmail
	static-libs tcmalloc +tools +zeekctl"

RDEPEND=">=dev-libs/caf-0.18.2:0=
	dev-libs/openssl:0=
	net-libs/libpcap
	sys-libs/zlib:0=
	curl? ( net-misc/curl )
	geoip2? ( dev-libs/libmaxminddb:0= )
	ipsumdump? ( net-analyzer/ipsumdump[ipv6?] )
	jemalloc? ( dev-libs/jemalloc:0= )
	kerberos? ( virtual/krb5 )
	python? ( ${PYTHON_DEPS}
		$(python_gen_cond_dep '>=dev-python/pybind11-2.6.1[${PYTHON_USEDEP}]')
	)
	sendmail? ( virtual/mta )
	tcmalloc? ( dev-util/google-perftools )"

DEPEND="${RDEPEND}"

BDEPEND=">=dev-lang/swig-3.0
	>=sys-devel/bison-2.5"

REQUIRED_USE="zeekctl? ( python )
	python? ( ${PYTHON_REQUIRED_USE} )"

PATCHES=(
	"${FILESDIR}"/${PN}-3.2-add-site-policy-dir-config.patch
	"${FILESDIR}"/${PN}-3.2-do-not-strip-broker-binary.patch
	"${FILESDIR}"/${PN}-3.2-fix-uninitialized-warning.patch
	"${FILESDIR}"/${PN}-4.2.0-do-not-install-wrapper-scripts.patch
	"${FILESDIR}"/${PN}-4.0.2-do-not-check-for-optional-dependencies.patch
	"${FILESDIR}"/${PN}-4.1.1-do-not-install-compat-assets.patch
	"${FILESDIR}"/${PN}-4.1.1-remove-unnecessary-remove.patch
)

src_prepare() {
	rm -rf auxil/broker/3rdparty/caf \
		auxil/broker/bindings/python/3rdparty \
		src/3rdparty/caf || die

	if use python; then
		sed -i 's:.*/3rdparty/pybind11/.*:if(DISABLE_PYTHON_BINDINGS):' \
			auxil/broker/CMakeLists.txt || die
		sed -i 's:.*/3rdparty/pybind11/.*::' \
			auxil/broker/bindings/python/CMakeLists.txt || die
	fi

	if ! use static-libs; then
		sed -i 's:add_library(paraglob STATIC:add_library(paraglob SHARED:' \
		auxil/paraglob/src/CMakeLists.txt
		sed -i 's:DESTINATION lib:DESTINATION ${INSTALL_LIB_DIR}:' \
		auxil/paraglob/src/CMakeLists.txt
	fi

	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-Wno-dev
		-DCAF_ROOT="${EPREFIX}/usr/include/caf"
		-DENABLE_DEBUG=$(usex debug)
		-DENABLE_JEMALLOC=$(usex jemalloc)
		-DENABLE_KRB5=$(usex kerberos)
		-DENABLE_MMDB=$(usex geoip2)
		-DENABLE_PERFTOOLS=$(usex tcmalloc)
		-DENABLE_STATIC=$(usex static-libs)
		-DBUILD_STATIC_BROKER=$(usex static-libs)
		-DBUILD_STATIC_BINPAC=$(usex static-libs)
		-DINSTALL_ZEEKCTL=$(usex zeekctl)
		-DINSTALL_AUX_TOOLS=$(usex tools)
		#https://github.com/zeek/zeek/issues/1493
		#-DENABLE_MOBILE_IPV6=$(usex ipv6)
		-DDISABLE_PYTHON_BINDINGS=$(usex python no yes)
		-DPYTHON_EXECUTABLE="${PYTHON}"
		-DZEEK_ETC_INSTALL_DIR="/etc/${PN}"
		-DPY_MOD_INSTALL_DIR="$(python_get_sitedir)"
		-DBINARY_PACKAGING_MODE=true
	)

	use debug && use tcmalloc && mycmakeargs+=( -DENABLE_PERFTOOLS_DEBUG=yes )
	use python && mycmakeargs+=( -DPYTHON_CONFIG="${PYTHON}-config" )
	use zeekctl && mycmakeargs+=(
		-DZEEK_LOG_DIR="/var/log/${PN}"
		-DZEEK_SPOOL_DIR="/var/spool/${PN}"
	)

	cmake_src_configure
}

src_install() {
	cmake_src_install

	use python && python_optimize \
		"${D}"/usr/"$(get_libdir)"/zeek/python/ \
		"${D}"/usr/"$(get_libdir)"/zeek/python/broker \
		"${D}"/usr/"$(get_libdir)"/zeek/python/zeekctl/ZeekControl \
		"${D}"/usr/"$(get_libdir)"/zeek/python/zeekctl/plugins

	keepdir /var/log/"${PN}" /var/spool/"${PN}"/{tmp,brokerstore}

	# Make sure local config does not get overwritten on reinstalls
	mv "${ED}"/usr/share/zeek/site "${ED}"/etc/zeek/ || die
}
