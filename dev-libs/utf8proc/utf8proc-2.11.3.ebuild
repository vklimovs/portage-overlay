# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="C library for processing UTF-8 encoded Unicode data"
HOMEPAGE="https://github.com/JuliaStrings/utf8proc"
# The test suite checks against the Unicode conformance data, which upstream's
# CMake otherwise file(DOWNLOAD)s at configure time (breaks under
# FEATURES=network-sandbox). -test-no-download.patch reads it from the source
# root instead; src_prepare supplies it from app-i18n/unicode-data.
SRC_URI="https://github.com/JuliaStrings/utf8proc/archive/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${P}"

# The generated utf8proc_data.c (Unicode Character Database derived) is compiled
# into libutf8proc.so; upstream LICENSE.md licenses that data under the Unicode
# Data Files and Software License (Gentoo "Unicode-DFS-2015" token).
LICENSE="MIT Unicode-DFS-2015"
# subslot = SONAME major of libutf8proc.so (currently .3, diverges from PV 2.x);
# re-derive from `objdump -p` on each bump.
SLOT="0/3"
KEYWORDS="~amd64"
IUSE="test"

# Unicode 17.0.0 conformance data for the test suite (see src_prepare).
BDEPEND="test? ( =app-i18n/unicode-data-17.0* )"

RESTRICT="!test? ( test )"

PATCHES=( "${FILESDIR}/${P}-test-no-download.patch" )

src_prepare() {
	cmake_src_prepare
	if use test; then
		# configure_file() in the patch picks these up from the source root.
		cp "${BROOT}"/usr/share/unicode-data/NormalizationTest.txt "${S}"/ || die
		cp "${BROOT}"/usr/share/unicode-data/auxiliary/GraphemeBreakTest.txt "${S}"/ || die
	fi
}

src_configure() {
	local mycmakeargs=(
		-DUTF8PROC_ENABLE_TESTING=$(usex test)
	)
	cmake_src_configure
}
