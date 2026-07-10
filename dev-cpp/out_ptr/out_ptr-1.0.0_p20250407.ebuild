# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

COMMIT="02a577edfcf25e2519e380a95c16743b7e5878a1"

DESCRIPTION="Header-only implementation of std::out_ptr for pre-C++23 compilers"
HOMEPAGE="https://github.com/soasis/out_ptr"
SRC_URI="https://github.com/soasis/out_ptr/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/out_ptr-${COMMIT}"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

src_install() {
	doheader -r include/ztd
}
