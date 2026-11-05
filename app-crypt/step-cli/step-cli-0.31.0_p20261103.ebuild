# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module shell-completion systemd toolchain-funcs

# Upstream tags rarely; ${PV}'s _pYYYYMMDD is this commit's date.
COMMIT="72da9dc97227953eaf950106f4cca919217c8ae8"

DESCRIPTION="Zero trust swiss army knife for X.509, OAuth, JWT and OATH OTP"
HOMEPAGE="https://github.com/smallstep/cli"

# To generate the vendor tarball:
#   tar -xf ${P}.tar.gz
#   cd cli-*/
#   go mod vendor
#   cd ..
#   tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
#       -cf - cli-*/vendor | xz -9e >"${P}-vendor.tar.xz"
SRC_URI="
	https://github.com/smallstep/cli/archive/${COMMIT}.tar.gz -> ${P}.tar.gz
	https://github.com/vklimovs/portage-overlay/releases/download/${P}-vendor.tar.xz/${P}-vendor.tar.xz
"
S="${WORKDIR}/cli-${COMMIT}"

# step-cli itself
LICENSE="Apache-2.0"
# Vendored package licenses
LICENSE+=" BSD BSD-2 MIT MPL-2.0"
SLOT="0"
KEYWORDS="~amd64"

# Both install /usr/bin/step.
RDEPEND="!kde-apps/step"
BDEPEND=">=dev-lang/go-1.26.0"

src_compile() {
	# Unset, BuildTime makes `step version` print the current time.
	ego build -trimpath \
		-ldflags "-X main.Version=${PV} -X main.BuildTime=${PV##*_p}" \
		./cmd/step

	if ! tc-is-cross-compiler; then
		local sh
		for sh in bash fish zsh; do
			./step completion "${sh}" >"step.${sh}" || die
		done
	fi
}

src_test() {
	# Dials smallstep.com.
	ego test -skip TestGetPeerCertificateServerName ./...
}

src_install() {
	dobin step
	einstalldocs
	systemd_dounit systemd/cert-renewer{.target,@.service,@.timer} \
		systemd/ssh-cert-renewer.{service,timer}

	if ! tc-is-cross-compiler; then
		newbashcomp step.bash step
		newfishcomp step.fish step.fish
		newzshcomp step.zsh _step
	fi
}
