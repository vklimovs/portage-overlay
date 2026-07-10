# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Userspace implementation of the kqueue event notification mechanism"
HOMEPAGE="https://github.com/mheily/libkqueue"
SRC_URI="https://github.com/mheily/libkqueue/archive/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${P}"

# Bulk of the compiled library is ISC (src/*); only the installed sys/event.h
# is BSD-2. Upstream LICENSE splits these as "== all source ==" / "== event.h ==".
LICENSE="ISC BSD-2"
# subslot = SONAME major of libkqueue.so (currently .0), not PV; re-derive from
# `objdump -p` on each bump.
SLOT="0/0"
KEYWORDS="~amd64"
IUSE="static-libs test"
RESTRICT="!test? ( test )"

src_prepare() {
	cmake_src_prepare
	# Drop upstream's unconditional -Werror (GNU) so new compiler warnings
	# don't become hard build failures.
	sed -i 's/ -Werror//' CMakeLists.txt || die
}

src_configure() {
	local mycmakeargs=(
		-DENABLE_STATIC=$(usex static-libs)
		-DENABLE_TESTING=$(usex test)
		-DVERSION_OVERRIDE=${PV}
	)
	cmake_src_configure
}
