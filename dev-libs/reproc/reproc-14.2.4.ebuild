# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic

DESCRIPTION="Cross-platform C/C++ library for starting and communicating with subprocesses"
HOMEPAGE="https://github.com/DaanDeMeyer/reproc"
SRC_URI="https://github.com/DaanDeMeyer/reproc/archive/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${P}"

LICENSE="MIT"
# Kept alongside newer versions because net-analyzer/zeek pins <14.2.5: 14.2.5
# made reproc::event::source::process by-value (was a reference), breaking the
# spicy that zeek bundles.
# subslot = SONAME major of libreproc++.so / libreproc.so (currently .14), not
# PV; re-derive from `objdump -p` on each bump.
SLOT="0/14"
KEYWORDS="~amd64"
IUSE="test"
RESTRICT="!test? ( test )"

src_configure() {
	# 14.2.4's public header trips GCC 14's -Wchanges-meaning (options::env /
	# options::redirect); upstream restructured it later. zeek's bundled spicy
	# silences it the same way. Gone in 14.2.7.
	append-cxxflags -Wno-changes-meaning

	local mycmakeargs=(
		-DREPROC++=ON
		-DREPROC_TEST=$(usex test)
	)
	cmake_src_configure
}

src_test() {
	# reproc-test-env runs a child with REPROC_ENV_EMPTY and asserts the child
	# sees ONLY the two vars it injected. Under FEATURES=sandbox that fails: the
	# sandbox force-injects LD_PRELOAD=libsandbox.so into every child, so the
	# environment is never truly empty. Not a reproc bug -- skip under sandbox.
	local CMAKE_SKIP_TESTS=( reproc-test-env )
	cmake_src_test
}
