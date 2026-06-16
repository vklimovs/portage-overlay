# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake-multilib

DESCRIPTION="The C++ Actor Framework (CAF)"
HOMEPAGE="https://www.actor-framework.org/"
SRC_URI="https://github.com/actor-framework/actor-framework/archive/${PV}.tar.gz
	-> ${P}.tar.gz"
S="${WORKDIR}/actor-framework-${PV}"

LICENSE="BSD"
SLOT="0/0.18.5"
KEYWORDS="~amd64 ~x86"
IUSE="debug doc examples +openssl static-libs test"
RESTRICT="!test? ( test )"

RDEPEND="
	openssl? ( dev-libs/openssl:0=[${MULTILIB_USEDEP},static-libs?] )
	examples? (
		net-misc/curl:=
		dev-libs/protobuf:= )"

DEPEND="${RDEPEND}"

BDEPEND="doc? (
	app-text/doxygen[dot]
	dev-python/sphinx
	dev-python/sphinx-rtd-theme )"

PATCHES=(
	"${FILESDIR}"/${P}-use-stable-version.patch
	"${FILESDIR}"/${P}-cstdint.patch
)

DOCS=( CHANGELOG.md README.md )

multilib_src_configure() {
	local mycmakeargs=(
		-DBUILD_SHARED_LIBS=$(usex static-libs no yes)
		-DCAF_ENABLE_ACTOR_PROFILER=$(usex debug)
		-DCAF_ENABLE_OPENSSL_MODULE=$(usex openssl)
		-DCAF_ENABLE_RUNTIME_CHECKS=$(usex debug)
		-DCAF_ENABLE_UTILITY_TARGETS=$(usex debug)
		-DCAF_LOG_LEVEL=$(usex debug DEBUG QUIET)
		-DLIBRARY_OUTPUT_PATH="$(get_libdir)"
	)

	if multilib_is_native_abi; then
		mycmakeargs+=(
			-DCAF_ENABLE_CURL_EXAMPLES=$(usex examples)
			-DCAF_ENABLE_EXAMPLES=$(usex examples)
			-DCAF_ENABLE_PROTOBUF_EXAMPLES=$(usex examples)
			-DCAF_ENABLE_TESTING=$(usex test)
		)
	else
		mycmakeargs+=(
			-DCAF_ENABLE_CURL_EXAMPLES=no
			-DCAF_ENABLE_EXAMPLES=no
			-DCAF_ENABLE_PROTOBUF_EXAMPLES=no
			-DCAF_ENABLE_TESTING=no
		)
	fi

	cmake_src_configure
}

multilib_src_compile() {
	cmake_src_compile

	if multilib_is_native_abi && use doc; then
		doxygen "${S}"/Doxyfile || die "doxygen failed"
		sphinx-build "${S}"/manual "${S}"/manual/html || die "sphinx failed"
	fi
}

multilib_src_test() {
	multilib_is_native_abi && cmake_src_test
}

multilib_src_install() {
	cmake_src_install

	if multilib_is_native_abi && use doc; then
		docinto api
		dodoc -r html/*
		docinto manual
		dodoc -r "${S}"/manual/html/*
	fi
}
