# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CMAKE_ECLASS=cmake
PYTHON_COMPAT=( python3_{6,7,8} )
inherit cmake-multilib python-single-r1

DESCRIPTION="The C++ Actor Framework (CAF)"
HOMEPAGE="https://actor-framework.org/"
SRC_URI="https://github.com/actor-framework/actor-framework/archive/${PV}.tar.gz
	-> ${P}.tar.gz"
LICENSE="|| ( Boost-1.0 BSD )"
SLOT="0/17.5"
KEYWORDS="~amd64 ~x86"
IUSE="debug doc examples opencl +openssl python static-libs test tools"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="examples? ( net-misc/curl[${MULTILIB_USEDEP}] )
	openssl? ( dev-libs/openssl:0=[${MULTILIB_USEDEP},static-libs?] )
	opencl? ( virtual/opencl[${MULTILIB_USEDEP}] )
	python? ( ${PYTHON_DEPS}
		$(python_gen_cond_dep '
			dev-python/ipython[${PYTHON_MULTI_USEDEP}]
			dev-python/pybind11[${PYTHON_MULTI_USEDEP}]
		')
	)"

DEPEND="${RDEPEND}"

BDEPEND="doc? ( app-doc/doxygen[dot]
	app-shells/bash:0
	dev-python/sphinx
	dev-python/sphinx_rtd_theme )"

RESTRICT="!test? ( test )"

S="${WORKDIR}/actor-framework-${PV}"

PATCHES=(
	"${FILESDIR}"/${PN}-use-ebuild-version.patch
)

src_prepare() {
	rm -rf libcaf_python/third_party || die

	if use python; then
		sed -i 's:.*/third_party/pybind/.*:if(FALSE):' \
			libcaf_python/CMakeLists.txt || die
		sed -i 's:.*pybind11/pybind11.h"$:#include "pybind11/pybind11.h":' \
			libcaf_python/src/main.cpp || die
	fi

	cmake_src_prepare

	sed -i "s:%%VERSION%%:\"${PV}\":" manual/conf.py || die
}

multilib_src_configure() {
	local no_python=yes
	multilib_is_native_abi && use python && no_python=no

	local mycmakeargs=(
		-DCAF_BUILD_STATIC="$(usex static-libs)"
		-DCAF_ENABLE_RUNTIME_CHECKS="$(usex debug)"
		-DCAF_LOG_LEVEL="$(usex debug DEBUG QUIET)"
		-DCAF_NO_EXAMPLES="$(usex examples no yes)"
		-DCAF_NO_OPENCL="$(usex opencl no yes)"
		-DCAF_NO_OPENSSL="$(usex openssl no yes)"
		-DCAF_NO_PYTHON="${no_python}"
		-DCAF_NO_TOOLS="$(usex tools no yes)"
		-DCAF_NO_UNIT_TESTS="$(usex test no yes)"
		-DCMAKE_SKIP_RPATH=yes
		-DLIBRARY_OUTPUT_PATH="$(get_libdir)"
	)

	cmake_src_configure
}

multilib_src_compile() {
	cmake_src_compile

	if multilib_is_native_abi && use doc; then
		cmake_build doxygen
		sphinx-build "${S}"/manual "${S}"/manual/html
	fi
}

multilib_src_test() {
	if multilib_is_native_abi; then
		local libdir libs
		libdir="$(get_libdir)"
		libs="${BUILD_DIR}/libcaf_core/${libdir}"
		libs="${libs}:${BUILD_DIR}/libcaf_io/${libdir}"

		use opencl && libs="${libs}:${BUILD_DIR}/libcaf_opencl/${libdir}"
		use openssl && libs="${libs}:${BUILD_DIR}/libcaf_openssl/${libdir}"
		use python && libs="${libs}:${BUILD_DIR}/libcaf_python/${libdir}"

		einfo "LD_LIBRARY_PATH is set to ${libs}"
		LD_LIBRARY_PATH="${libs}" cmake_src_test
	fi
}

multilib_src_install() {
	cmake_src_install

	if multilib_is_native_abi && use doc; then
		docinto api
		dodoc -r doc/html/*
		docinto manual
		dodoc -r "${S}"/manual/html/*
	fi
}
