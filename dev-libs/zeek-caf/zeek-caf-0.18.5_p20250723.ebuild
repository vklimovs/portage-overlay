# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

# Zeek's Broker bundles its own fork of CAF (github.com/zeek/actor-framework),
# pinned by commit. It is version-stamped 0.18.5 (CAF_VERSION 1805) but diverges
# heavily from upstream 0.18.5 -- the entire CAF streaming subsystem is removed --
# so it is NOT interchangeable with dev-libs/caf and deliberately blocks it
# (see RDEPEND). This package exists purely so net-analyzer/zeek can drop its
# vendored copy and link a real, minimal, separately-versioned CAF instead.
#
# COMMIT is the caf submodule pin. zeek 8.0.8, 8.0.9, 8.2.0 and 8.2.1 all
# point here. Re-verify on every zeek bump -- it must match the caf gitlink at:
#   github.com/zeek/zeek @ vX.Y.Z  ->  auxil/broker  ->  caf
# The _pYYYYMMDD in ${PV} is this commit's date.
COMMIT="4aa660d003d8bbb922a33fb7a31f80d9d3271262"

DESCRIPTION="Minimal CAF (C++ Actor Framework) fork used by Zeek's Broker"
HOMEPAGE="https://github.com/zeek/actor-framework"
SRC_URI="https://github.com/zeek/actor-framework/archive/${COMMIT}.tar.gz
	-> ${P}.tar.gz"
S="${WORKDIR}/actor-framework-${COMMIT}"

LICENSE="BSD"
# Same SONAME/ABI line and install paths as the real dev-libs/caf:0/0.18.5, so
# the two cannot coexist. We only ever install one CAF; Broker links this one.
SLOT="0/0.18.5"
KEYWORDS="~amd64"

# Installs files identical to dev-libs/caf (libcaf_*.so, /usr/include/caf,
# cmake/CAF config); weak blocker lets portage swap the two cleanly.
RDEPEND="!dev-libs/caf"

src_configure() {
	# Broker links CAF::core/io/net (all on by default at this pin). Turn off
	# everything else: the OpenSSL module (Broker does its own OpenSSL), the
	# caf-run tools, the unit-test suites, and the examples.
	local mycmakeargs=(
		-DCAF_ENABLE_OPENSSL_MODULE=OFF
		-DCAF_ENABLE_TOOLS=OFF
		-DCAF_ENABLE_TESTING=OFF
		-DCAF_ENABLE_EXAMPLES=OFF
	)

	cmake_src_configure
}
