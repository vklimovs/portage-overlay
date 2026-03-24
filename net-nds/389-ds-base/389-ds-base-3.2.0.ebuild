# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CRATES="
	addr2line@0.24.2
	adler2@2.0.1
	allocator-api2@0.2.21
	atty@0.2.14
	autocfg@1.5.0
	backtrace@0.3.75
	base64@0.13.1
	bitflags@1.3.2
	bitflags@2.9.1
	byteorder@1.5.0
	cbindgen@0.26.0
	cc@1.2.27
	cfg-if@1.0.1
	clap@3.2.25
	clap_lex@0.2.4
	concread@0.5.6
	crossbeam-epoch@0.9.18
	crossbeam-queue@0.3.12
	crossbeam-utils@0.8.21
	equivalent@1.0.2
	errno@0.3.12
	fastrand@2.3.0
	fernet@0.1.4
	foldhash@0.1.5
	foreign-types@0.3.2
	foreign-types-shared@0.1.1
	getrandom@0.2.16
	getrandom@0.3.3
	gimli@0.31.1
	hashbrown@0.12.3
	hashbrown@0.15.4
	heck@0.4.1
	hermit-abi@0.1.19
	indexmap@1.9.3
	itoa@1.0.15
	jobserver@0.1.33
	libc@0.2.174
	linux-raw-sys@0.9.4
	log@0.4.27
	lru@0.13.0
	memchr@2.7.5
	miniz_oxide@0.8.9
	object@0.36.7
	once_cell@1.21.3
	openssl@0.10.73
	openssl-macros@0.1.1
	openssl-sys@0.9.109
	os_str_bytes@6.6.1
	paste@0.1.18
	paste-impl@0.1.18
	pin-project-lite@0.2.16
	pkg-config@0.3.32
	proc-macro-hack@0.5.20+deprecated
	proc-macro2@1.0.95
	quote@1.0.40
	r-efi@5.3.0
	rustc-demangle@0.1.25
	rustix@1.0.7
	ryu@1.0.20
	serde@1.0.219
	serde_derive@1.0.219
	serde_json@1.0.140
	shlex@1.3.0
	smallvec@1.15.1
	sptr@0.3.2
	strsim@0.10.0
	syn@1.0.109
	syn@2.0.103
	tempfile@3.20.0
	termcolor@1.4.1
	textwrap@0.16.2
	tokio@1.45.1
	toml@0.5.11
	tracing@0.1.41
	tracing-attributes@0.1.30
	tracing-core@0.1.34
	unicode-ident@1.0.18
	uuid@0.8.2
	vcpkg@0.2.15
	wasi@0.11.1+wasi-snapshot-preview1
	wasi@0.14.2+wasi-0.2.4
	winapi@0.3.9
	winapi-i686-pc-windows-gnu@0.4.0
	winapi-util@0.1.9
	winapi-x86_64-pc-windows-gnu@0.4.0
	windows-sys@0.59.0
	windows-targets@0.52.6
	windows_aarch64_gnullvm@0.52.6
	windows_aarch64_msvc@0.52.6
	windows_i686_gnu@0.52.6
	windows_i686_gnullvm@0.52.6
	windows_i686_msvc@0.52.6
	windows_x86_64_gnu@0.52.6
	windows_x86_64_gnullvm@0.52.6
	windows_x86_64_msvc@0.52.6
	wit-bindgen-rt@0.39.0
	zeroize@1.8.1
	zeroize_derive@1.4.2
"

PYTHON_COMPAT=( python3_{11..14} )

DISTUTILS_SINGLE_IMPL=1
DISTUTILS_USE_PEP517=setuptools

inherit autotools cargo distutils-r1 readme.gentoo-r1 systemd tmpfiles

DESCRIPTION="389 Directory Server (core libraries and daemons)"
HOMEPAGE="https://directory.fedoraproject.org/"
SRC_URI="
	https://github.com/389ds/${PN}/archive/refs/tags/${P}.tar.gz
	${CARGO_CRATE_URIS}
"
S="${WORKDIR}/${PN}-${P}"

LICENSE="GPL-3+"
# Dependent crate licenses
LICENSE+=" Apache-2.0 BSD MIT MPL-2.0 Unicode-DFS-2016"

SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="+accountpolicy +autobind auto-dn-suffix +bitwise debug +dna doc +ldapi +pam-passthru selinux systemd"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# lib389 tests (which is most of the suite) can't find their own modules.
RESTRICT="test"

# Do not add any AGPL-3 BDB here!
# See bug 525110, comment 15.
DEPEND="
	>=app-crypt/mit-krb5-1.7-r100[openldap]
	dev-db/lmdb:=
	>=dev-libs/cyrus-sasl-2.1.19:2[kerberos]
	>=dev-libs/icu-60.2:=
	dev-libs/json-c:=
	dev-libs/libpcre2:=
	dev-libs/nspr
	>=dev-libs/nss-3.22[utils]
	dev-libs/openssl:0=
	>=net-analyzer/net-snmp-5.1.2:=
	net-nds/openldap:=[sasl]
	sys-fs/e2fsprogs
	sys-libs/cracklib
	sys-libs/db:5.3
	virtual/libcrypt:=
	virtual/zlib:=
	pam-passthru? ( sys-libs/pam )
	selinux? (
		$(python_gen_cond_dep '
			sys-libs/libselinux[python,${PYTHON_USEDEP}]
		')
	)
	systemd? ( >=sys-apps/systemd-244 )
"

BDEPEND=">=dev-build/autoconf-2.69-r5
	virtual/pkgconfig
	${PYTHON_DEPS}
	$(python_gen_cond_dep '
		dev-python/argparse-manpage[${PYTHON_USEDEP}]
	')
	doc? ( app-text/doxygen )
	test? ( dev-util/cmocka )
"

# perl dependencies are for logconv.pl
RDEPEND="${DEPEND}
	acct-user/dirsrv
	${PYTHON_DEPS}
	$(python_gen_cond_dep '
		dev-python/argcomplete[${PYTHON_USEDEP}]
		dev-python/cryptography[${PYTHON_USEDEP}]
		dev-python/distro[${PYTHON_USEDEP}]
		dev-python/psutil[${PYTHON_USEDEP}]
		dev-python/pyasn1[${PYTHON_USEDEP}]
		dev-python/pyasn1-modules[${PYTHON_USEDEP}]
		dev-python/python-dateutil[${PYTHON_USEDEP}]
		dev-python/python-ldap[sasl,${PYTHON_USEDEP}]
	')
	virtual/logger
	virtual/perl-Archive-Tar
	virtual/perl-DB_File
	virtual/perl-Getopt-Long
	virtual/perl-IO
	virtual/perl-IO-Compress
	virtual/perl-MIME-Base64
	virtual/perl-Scalar-List-Utils
	virtual/perl-Time-Local
	selinux? ( sec-policy/selinux-dirsrv )
"

PATCHES=(
	"${FILESDIR}/${PN}-3.2.0-fix-db-version-detection-hardened.patch"
	"${FILESDIR}/${PN}-3.2.0-fix-configure-rust-variable-collision.patch"
)

EPYTEST_PLUGINS=()
distutils_enable_tests pytest

pkg_setup() {
	python-single-r1_pkg_setup
	rust_pkg_setup
}

src_prepare() {
	# according to an upstream comment, this got committed by accident
	rm src/librslapd/Cargo.lock || die

	# https://github.com/389ds/389-ds-base/issues/4292
	if use !systemd; then
		sed -i \
			-e 's|WITH_SYSTEMD = 1|WITH_SYSTEMD = 0|' \
			Makefile.am || die
	fi

	default

	eautoreconf
}

src_configure() {
	local myeconfargs=(
		$(use_enable accountpolicy acctpolicy)
		$(use_enable bitwise)
		$(use_enable dna)
		$(use_enable pam-passthru)
		$(use_enable autobind)
		$(use_enable auto-dn-suffix)
		$(use_enable debug)
		$(use_enable ldapi)
		$(use_with selinux)
		$(use_with !systemd initddir "/etc/init.d")
		$(use_with systemd)
		$(use_enable test cmocka)
		--with-systemdgroupname="dirsrv.target"
		--with-tmpfiles-d="${EPREFIX}/usr/lib/tmpfiles.d"
		--with-systemdsystemunitdir="$(systemd_get_systemunitdir)"
		--enable-rust-offline
		--with-pythonexec="${PYTHON}"
		--with-fhs
		--with-openldap
		--with-db-inc="${EPREFIX}"/usr/include/db5.3
		--with-libbdb-ro=no
		--disable-cockpit
	)

	econf "${myeconfargs[@]}"

	# generated by configure from .cargo/config.toml.in; remove it so
	# cargo --offline uses ECARGO_HOME instead of the vendored registry
	rm .cargo/config.toml || die
}

src_compile() {
	export CARGO_HOME="${ECARGO_HOME}"

	default

	if use doc; then
		doxygen docs/slapi.doxy || die
	fi

	pushd src/lib389 &>/dev/null || die
		distutils-r1_src_compile
	popd &>/dev/null || die
}

src_test() {
	emake check
	distutils-r1_src_test
}

src_install() {
	# -j1 is a temporary workaround for bug #605432
	emake -j1 DESTDIR="${D}" install

	newinitd "${FILESDIR}"/389-ds.initd-r1 389-ds
	newinitd "${FILESDIR}"/389-ds-snmp.initd 389-ds-snmp

	dotmpfiles "${FILESDIR}"/389-ds-base.conf

	# cope with libraries being in /usr/lib/dirsrv
	dodir /etc/env.d
	echo "LDPATH=/usr/$(get_libdir)/dirsrv" > "${ED}"/etc/env.d/08dirsrv || die

	if use doc; then
		docinto html/
		dodoc -r html/.
	fi

	pushd src/lib389 &>/dev/null || die
		distutils-r1_src_install
	popd &>/dev/null || die

	# build_manpages installs man pages to man1/ in addition to the correct
	# man8/ location (via [tool.setuptools.data-files]); remove duplicates
	rm -f "${ED}"/usr/share/man/man1/{dsconf,dsctl,dscreate,dsidm,openldap_to_ds}.8 || die

	python_fix_shebang "${ED}"
	python_optimize

	readme.gentoo_create_doc

	find "${ED}" -type f \( -name "*.a" -o -name "*.la" \) -delete || die
}

pkg_postinst() {
	tmpfiles_process 389-ds-base.conf

	readme.gentoo_print_elog
}
