# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

# Note: Keep EGO_VENDOR in sync with Godeps
EGO_VENDOR=(
	"collectd.org e84e8af github.com/collectd/go-collectd"
	"github.com/BurntSushi/toml a368813"
	"github.com/RoaringBitmap/roaring cefad6e"
	"github.com/beorn7/perks 4c0e845"
	"github.com/bmizerany/pat c068ca2"
	"github.com/boltdb/bolt 4b1ebc1"
	"github.com/cespare/xxhash 1b6d2e4"
	"github.com/davecgh/go-spew 346938d"
	"github.com/dgrijalva/jwt-go 24c63f5"
	"github.com/dgryski/go-bits 2ad8d70"
	"github.com/dgryski/go-bitstream 7d46cd2"
	"github.com/glycerine/go-unsnap-stream 62a9a9e"
	"github.com/gogo/protobuf 1c2b16b"
	"github.com/golang/protobuf 1e59b77"
	"github.com/golang/snappy d9eb7a3"
	"github.com/google/go-cmp 18107e6"
	"github.com/influxdata/influxql c0a433a"
	"github.com/influxdata/usage-client 6d38953"
	"github.com/influxdata/yamux 1f58ded"
	"github.com/influxdata/yarpc 036268c"
	"github.com/jsternberg/zap-logfmt 5ea5386"
	"github.com/jwilder/encoding 2789473"
	"github.com/mattn/go-isatty 6ca4dbf"
	"github.com/matttproud/golang_protobuf_extensions c12348c"
	"github.com/opentracing/opentracing-go 1361b9c"
	"github.com/paulbellamy/ratecounter 5a11f58"
	"github.com/peterh/liner 8860952"
	"github.com/philhofer/fwd 1612a29"
	"github.com/prometheus/client_golang 661e31b"
	"github.com/prometheus/client_model 99fa1f4"
	"github.com/prometheus/common 2e54d0b"
	"github.com/prometheus/procfs a6e9df8"
	"github.com/retailnext/hllpp 38a7bb7"
	"github.com/tinylib/msgp ad0ff2e"
	"github.com/xlab/treeprint 06dfc6f"
	"github.com/xlab/treeprint 06dfc6f"
	"go.uber.org/atomic 54f72d3 github.com/uber-go/atomic"
	"go.uber.org/multierr fb7d312 github.com/uber-go/multierr"
	"go.uber.org/zap 35aad58 github.com/uber-go/zap"
	"golang.org/x/crypto 9477e0b github.com/golang/crypto"
	"golang.org/x/net 9dfe398 github.com/golang/net"
	"golang.org/x/sync fd80eb9 github.com/golang/sync"
	"golang.org/x/sys 062cd7e github.com/golang/sys"
	"golang.org/x/text a71fd10 github.com/golang/text"
	"golang.org/x/time 6dc1736 github.com/golang/time"
)

inherit golang-vcs-snapshot systemd user

MY_PV="${PV/_/}"
COMMIT_HASH="60d27e6"
EGO_PN="github.com/influxdata/${PN}"
DESCRIPTION="Scalable datastore for metrics, events, and real-time analytics"
HOMEPAGE="https://influxdata.com"
SRC_URI="https://${EGO_PN}/archive/v${MY_PV}.tar.gz -> ${P}.tar.gz
	${EGO_VENDOR_URI}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="man"

DEPEND="man? ( app-text/asciidoc
	app-text/xmlto )"
RESTRICT="mirror strip"

G="${WORKDIR}/${P}"
S="${G}/src/${EGO_PN}"

pkg_setup() {
	enewgroup influxdb
	enewuser influxdb -1 -1 /var/lib/influxdb influxdb
}

src_prepare() {
	# By default InfluxDB sends anonymous statistics to
	# usage.influxdata.com, let's disable this by default.
	sed -i "s:# reporting.*:reporting-disabled = true:" \
		etc/config.sample.toml || die

	default
}

src_compile() {
	export GOPATH="${G}"
	local GOLDFLAGS="-s -w \
		-X main.version=${MY_PV} \
		-X main.branch=non-git \
		-X main.commit=${COMMIT_HASH}"

	go install -v -ldflags "${GOLDFLAGS}" \
		./cmd/influx{,d,_stress,_inspect,_tsm} || die

	use man && emake -C man
}

src_install() {
	dobin "${G}"/bin/influx{,d,_stress,_inspect,_tsm}

	newinitd "${FILESDIR}"/${PN}.initd-r2 ${PN}
	systemd_install_serviced "${FILESDIR}"/${PN}.service.conf
	systemd_dounit scripts/${PN}.service
	systemd_newtmpfilesd "${FILESDIR}"/${PN}.tmpfilesd-r1 ${PN}.conf

	insinto /etc/influxdb
	newins etc/config.sample.toml influxdb.conf.example

	use man && doman man/*.1

	diropts -o influxdb -g influxdb -m 0750
	dodir /var/log/influxdb
}

src_test() {
	go fmt ./... || die
	go test -v -short -timeout 5m ./... || die
}

pkg_postinst() {
	if [ ! -e "${EROOT%/}"/etc/${PN}/influxdb.conf ]; then
		elog "No influxdb.conf found, copying the example over"
		cp "${EROOT%/}"/etc/${PN}/influxdb.conf{.example,} || die
	else
		elog "influxdb.conf found, please check example file for possible changes"
	fi
}
