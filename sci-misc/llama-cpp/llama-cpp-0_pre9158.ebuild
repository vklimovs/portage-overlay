# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ROCM_VERSION="6.3"

inherit cmake cuda rocm linux-info

DESCRIPTION="Port of Facebook's LLaMA model in C/C++"
HOMEPAGE="https://github.com/ggml-org/llama.cpp"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/ggml-org/llama.cpp.git"
else
	MY_PV="b${PV#0_pre}"
	SRC_URI="https://github.com/ggml-org/llama.cpp/archive/refs/tags/${MY_PV}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/llama.cpp-${MY_PV}"
	KEYWORDS="~amd64"
fi

LICENSE="MIT"
SLOT="0"
CPU_FLAGS_X86=( avx avx2 f16c )
IUSE="blis curl cuda flexiblas openblas opencl +openmp openssl rocm vulkan wmma"

REQUIRED_USE="
	?? ( blis flexiblas openblas )
	rocm? ( ${ROCM_REQUIRED_USE} )
	wmma? ( rocm )
"

RESTRICT="test"

CDEPEND="
	blis? ( sci-libs/blis:= )
	curl? ( net-misc/curl:= )
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	flexiblas? ( sci-libs/flexiblas:= )
	openblas? ( sci-libs/openblas:= )
	openmp? ( llvm-runtimes/openmp:= )
	openssl? ( dev-libs/openssl:= )
	rocm? (
		>=dev-util/hip-${ROCM_VERSION}:=
		>=sci-libs/hipBLAS-${ROCM_VERSION}:=[${ROCM_USEDEP}]
		wmma? ( >=sci-libs/rocWMMA-${ROCM_VERSION}:=[${ROCM_USEDEP}] )
	)
"
DEPEND="${CDEPEND}
	opencl? ( dev-util/opencl-headers )
	vulkan? (
		dev-util/spirv-headers
		dev-util/vulkan-headers
	)
"
RDEPEND="${CDEPEND}
	opencl? ( dev-libs/opencl-icd-loader )
	vulkan? ( media-libs/vulkan-loader )
"
BDEPEND="vulkan? ( media-libs/shaderc )"

PATCHES=(
	"${FILESDIR}/${PN}-blas-ld.patch"
)

pkg_setup() {
	if use rocm; then
		linux-info_pkg_setup
		if linux-info_get_any_version && linux_config_exists; then
			if ! linux_chkconfig_present HSA_AMD_SVM; then
				ewarn "To use ROCm/HIP, enable HSA_AMD_SVM in your kernel."
			fi
		fi
	fi
}

src_prepare() {
	use cuda && cuda_src_prepare
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DBUILD_NUMBER="${PV#0_pre}"
		-DCMAKE_INSTALL_LIBDIR="${EPREFIX}/usr/$(get_libdir)/llama.cpp"
		-DCMAKE_INSTALL_RPATH="${EPREFIX}/usr/$(get_libdir)/llama.cpp"
		-DCMAKE_SKIP_BUILD_RPATH=ON
		-DGGML_CUDA=$(usex cuda ON OFF)
		-DGGML_NATIVE=OFF
		-DGGML_OPENCL=$(usex opencl ON OFF)
		-DGGML_OPENMP=$(usex openmp ON OFF)
		-DGGML_RPC=ON
		-DGGML_VULKAN=$(usex vulkan ON OFF)
		-DLLAMA_BUILD_EXAMPLES=OFF
		-DLLAMA_BUILD_SERVER=ON
		-DLLAMA_BUILD_TESTS=OFF
		-DLLAMA_CURL=$(usex curl ON OFF)
		-DLLAMA_OPENSSL=$(usex openssl ON OFF)
	)

	if use blis; then
		mycmakeargs+=( -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=FLAME )
	elif use flexiblas; then
		mycmakeargs+=( -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=FlexiBLAS )
	elif use openblas; then
		mycmakeargs+=( -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS )
	fi

	if use cuda; then
		local -x CUDAHOSTCXX="$(cuda_gccdir)"
		cuda_add_sandbox
		addpredict "/dev/char/"
	fi

	if use rocm; then
		rocm_use_hipcc
		mycmakeargs+=(
			-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
			-DGGML_HIP=ON
			-DGGML_HIP_ROCWMMA_FATTN=$(usex wmma ON OFF)
		)
	fi

	cmake_src_configure
}

src_install() {
	cmake_src_install
	dobin "${BUILD_DIR}/bin/rpc-server"

	rm "${ED}/usr/bin/convert_hf_to_gguf.py" || die
}
