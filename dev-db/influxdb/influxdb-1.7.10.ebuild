# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

EGO_PN=github.com/influxdata/${PN}
EGO_VENDOR=(
	"cloud.google.com/go v0.51.0 github.com/googleapis/google-cloud-go"
	"collectd.org v0.3.0 github.com/collectd/go-collectd"
	"github.com/BurntSushi/toml v0.3.1"
	"github.com/Masterminds/semver v1.4.2"
	"github.com/alecthomas/kingpin v2.2.6"
	"github.com/alecthomas/template a0175ee3bccc"
	"github.com/alecthomas/units 2efee857e7cf"
	"github.com/apache/arrow/ af6fa24be0db"
	"github.com/apex/log v1.1.0"
	"github.com/aws/aws-sdk-go v1.25.16"
	"github.com/beorn7/perks v1.0.0"
	"github.com/blakesmith/ar 8bd4349a67f2"
	"github.com/bmizerany/pat 6226ea591a40"
	"github.com/boltdb/bolt v1.3.1"
	"github.com/c-bata/go-prompt v0.2.2"
	"github.com/caarlos0/ctrlc v1.0.0"
	"github.com/campoy/unique 88950e537e7e"
	"github.com/cespare/xxhash v1.1.0"
	"github.com/davecgh/go-spew v1.1.1"
	"github.com/dgrijalva/jwt-go v3.2.0"
	"github.com/dgryski/go-bitstream 3522498ce2c8"
	"github.com/eclipse/paho.mqtt.golang v1.2.0"
	"github.com/emirpasic/gods v1.9.0"
	"github.com/fatih/color v1.7.0"
	"github.com/glycerine/go-unsnap-stream 9f0cb55181dd"
	"github.com/go-sql-driver/mysql v1.4.1"
	"github.com/gogo/protobuf v1.1.1"
	"github.com/golang/groupcache 215e87163ea7"
	"github.com/golang/protobuf v1.3.2"
	"github.com/golang/snappy 2e65f85255db"
	"github.com/google/go-cmp v0.4.0"
	"github.com/google/go-github v17.0.0"
	"github.com/google/go-querystring v1.0.0"
	"github.com/googleapis/gax-go v2.0.5"
	"github.com/goreleaser/goreleaser v0.94.0"
	"github.com/goreleaser/nfpm v0.9.7"
	"github.com/imdario/mergo v0.3.6"
	"github.com/inconshreveable/mousetrap v1.0.0"
	"github.com/influxdata/changelog v1.1.0"
	"github.com/influxdata/flux v0.50.2"
	"github.com/influxdata/influxql v1.0.1"
	"github.com/influxdata/line-protocol a3afd890113f"
	"github.com/influxdata/roaring fc520f41fab6"
	"github.com/influxdata/tdigest bf2b5ad3c0a9"
	"github.com/influxdata/usage-client 6d3895376368"
	"github.com/jbenet/go-context d14ea06fba99"
	"github.com/jmespath/go-jmespath c2b33e8439af"
	"github.com/jstemmer/go-junit-report v0.9.1"
	"github.com/jsternberg/zap-logfmt v1.0.0"
	"github.com/jwilder/encoding b4e1701a28ef"
	"github.com/kevinburke/ssh_config 81db2a75821e"
	"github.com/klauspost/compress v1.4.0"
	"github.com/klauspost/cpuid ae7887de9fa5"
	"github.com/klauspost/crc32 cb6bfca970f6"
	"github.com/klauspost/pgzip 0bf5dcad4ada"
	"github.com/lib/pq v1.0.0"
	"github.com/mattn/go-colorable v0.0.9"
	"github.com/mattn/go-isatty v0.0.4"
	"github.com/mattn/go-runewidth v0.0.3"
	"github.com/mattn/go-tty 13ff1204f104"
	"github.com/mattn/go-zglob v0.0.1"
	"github.com/matttproud/golang_protobuf_extensions v1.0.1"
	"github.com/mitchellh/go-homedir v1.1.0"
	"github.com/mschoch/smat 90eadee771ae"
	"github.com/opentracing/opentracing-go v1.0.2"
	"github.com/paulbellamy/ratecounter v0.2.0"
	"github.com/pelletier/go-buffruneio v0.2.0"
	"github.com/peterh/liner 8c1271fcf47f"
	"github.com/philhofer/fwd v1.0.0"
	"github.com/pkg/errors v0.8.1"
	"github.com/pkg/term bffc007b7fd5"
	"github.com/prometheus/client_golang v1.0.0"
	"github.com/prometheus/client_model 14fe0d1b01d4"
	"github.com/prometheus/common v0.6.0"
	"github.com/prometheus/procfs v0.0.2"
	"github.com/retailnext/hllpp 101a6d2f8b52"
	"github.com/satori/go.uuid v1.2.0"
	"github.com/segmentio/kafka-go v0.2.2"
	"github.com/sergi/go-diff v1.0.0"
	"github.com/spf13/cast v1.3.0"
	"github.com/spf13/cobra v0.0.3"
	"github.com/spf13/pflag v1.0.3"
	"github.com/src-d/gcfg v1.4.0"
	"github.com/tinylib/msgp v1.0.2"
	"github.com/willf/bitset v1.1.3"
	"github.com/xanzy/ssh-agent v0.2.0"
	"github.com/xlab/treeprint d6fb6747feb6"
	"go.opencensus.io v0.22.2 github.com/census-instrumentation/opencensus-go"
	"go.uber.org/atomic v1.3.2 github.com/uber-go/atomic"
	"go.uber.org/multierr v1.1.0 github.com/uber-go/multierr"
	"go.uber.org/zap v1.9.1 github.com/uber-go/zap"
	"golang.org/x/crypto 87dc89f01550 github.com/golang/crypto"
	"golang.org/x/exp da58074b4299 github.com/golang/exp"
	"golang.org/x/lint fdd1cda4f05f github.com/golang/lint"
	"golang.org/x/net c0dbc17a3553 github.com/golang/net"
	"golang.org/x/oauth2 bf48bf16ab8d github.com/golang/oauth2"
	"golang.org/x/sync cd5d95a43a6e github.com/golang/sync"
	"golang.org/x/sys 548cf772de50 github.com/golang/sys"
	"golang.org/x/text v0.3.2 github.com/golang/text"
	"golang.org/x/time 9d24e82272b4 github.com/golang/time"
	"golang.org/x/tools 89082a384178 github.com/golang/tools"
	"golang.org/x/xerrors 9bdfabe68543 github.com/golang/xerrors"
	"gonum.org/v1/gonum v0.6.0 github.com/gonum/gonum"
	"google.golang.org/api v0.15.0 github.com/googleapis/google-api-go-client"
	"google.golang.org/appengine v1.6.5 github.com/golang/appengine"
	"google.golang.org/genproto bd8f9a0ef82f github.com/google/go-genproto"
	"google.golang.org/grpc v1.26.0 github.com/grpc/grpc-go"
	"gopkg.in/src-d/go-billy.v4 v4.2.1 github.com/src-d/go-billy"
	"gopkg.in/src-d/go-git.v4 v4.8.1 github.com/src-d/go-git"
	"gopkg.in/warnings.v0 v0.1.2 github.com/go-warnings/warnings"
	"gopkg.in/yaml.v2 v2.2.2 github.com/go-yaml/yaml"
	"honnef.co/go/tools v0.0.1-2019.2.3 github.com/dominikh/go-tools"
)

inherit golang-build golang-vcs-snapshot systemd

DESCRIPTION=" Scalable datastore for metrics, events, and real-time analytics"
HOMEPAGE="https://www.influxdata.com"
SRC_URI="https://${EGO_PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
	${EGO_VENDOR_URI}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND=">=app-text/asciidoc-8.6.10
	acct-group/nfsen
	acct-user/nfsen
	app-text/xmlto"

src_compile() {
	pushd "src/${EGO_PN}" > /dev/null || die
	set -- env GOPATH="${S}" go build -v -work -x ./...
	echo "$@"
	"$@" || die "compile failed"
	cd man
	emake build
	popd > /dev/null
}

src_install() {
	pushd "src/${EGO_PN}" > /dev/null || die
	set -- env GOPATH="${S}" go install -v -work -x ./...
	echo "$@"
	"$@" || die
	dobin "${S}"/bin/influx*
	dodoc CHANGELOG.md etc/config.sample.toml
	doman man/*.1
	insinto /etc/logrotate.d
	newins scripts/logrotate influxdb
	systemd_dounit scripts/influxdb.service
	newconfd "${FILESDIR}"/influxdb.confd influxdb
	newinitd "${FILESDIR}"/influxdb.rc influxdb
	insinto /etc/influxdb
	doins "${FILESDIR}"/influxd.conf
	keepdir /var/log/influxdb
	fowners influxdb:influxdb /var/log/influxdb
	popd > /dev/null || die
}
