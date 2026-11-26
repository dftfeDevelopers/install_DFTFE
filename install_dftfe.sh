#!/bin/bash
# Install DFT-FE and its dependencies on ALCF Polaris. See README.md for the options.
trap "pkill -P $$ wget; exit 1" INT
set -eo pipefail
source "$(dirname "$0")/dftfe_env_polaris.sh"

nprocs=8
branch=publicGithubDevelop
dftfeRepo=https://github.com/dftfeDevelopers/dftfe.git

mpi_c_compiler=cc
mpi_cxx_compiler=CC
mpi_fortran_compiler=ftn
c_compiler=gcc-14
cxx_compiler=g++-14
fortran_compiler=gfortran-14
export NVCC_CCBIN=$cxx_compiler
opt_flags="-O2 -fPIC -march=znver3"
openmp_flag="-fopenmp"
device_architectures="80-real"

libsciDir=$CRAY_LIBSCI_PREFIX_DIR/lib
lapackLibs=$libsciDir/libsci_gnu_mp.so
scalapackLibs="-L$libsciDir -lsci_gnu_mpi_mp -lsci_gnu_mp"

#DFT-FE options
withGPUAwareMPI=OFF
withDCCL=OFF
withHigherQuadPSP=ON
minimalCompile=ON
useInt64=ON
testing=ON
elpaWithOpenMP=ON

stages=(alglib libxc spglib libxml2 numdiff p4est kokkos boost dealii elpa dftd dftfe)

download= build= cleanSrc=
declare -A want
for arg in "$@"; do
  case "$arg" in
    --nprocs=*)          nprocs=${arg#--nprocs=} ;;
    --branch=*)          branch=${arg#--branch=} ;;
    --repo=*)            dftfeRepo=${arg#--repo=} ;;
    --download)          download=true ;;
    --build)             build=true ;;
    --all)               download=true; build=true ;;
    --clean-build-files) cleanSrc=true ;;
    --*)                 want[${arg#--}]=true ;;
  esac
done
if [[ $build ]]; then
  for pkg in "${stages[@]}"; do [ $pkg = dftd ] || want[$pkg]=true; done
fi

depDir=$DFTFE_DEPS
srcDir=$depDir/src
dftfeDir=$DFTFE_PREFIX/dftfe_$branch
logDir=$DFTFE_PREFIX/logs
mkdir -p "$srcDir" "$depDir"/{lib,include,bin} "$dftfeDir"/{src,install} "$logDir"

if [[ $download ]]; then
  cd "$srcDir"
  wget -N -q --show-progress https://www.alglib.net/translator/re/alglib-4.07.0.cpp.gpl.tgz &
  wget -N -q --show-progress https://gitlab.com/libxc/libxc/-/archive/7.1.2/libxc-7.1.2.tar.gz &
  wget -N -q --show-progress https://github.com/spglib/spglib/archive/refs/tags/v2.7.0.tar.gz &
  wget -N -q --show-progress https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz &
  wget -N -q --show-progress https://download.savannah.gnu.org/releases/numdiff/numdiff-5.9.0.tar.gz &
  wget -N -q --show-progress https://p4est.github.io/release/p4est-2.8.7.tar.gz &
  wget -N -q --show-progress https://github.com/kokkos/kokkos/archive/refs/tags/4.7.02.tar.gz &
  wget -N -q --show-progress https://archives.boost.io/release/1.92.0/source/boost_1_92_0.tar.bz2 &
  # deal.II 9.8 removed IndexSet::fill_index_vector();
  wget -N -q --show-progress https://github.com/dealii/dealii/releases/download/v9.8.0/dealii-9.8.0.tar.gz &
  wget -N -q --show-progress https://elpa.mpcdf.mpg.de/software/tarball-archive/Releases/2026.02.002/elpa-2026.02.002.tar.gz &
  wget -N -q --show-progress https://github.com/dftd4/dftd4/archive/refs/tags/v4.2.0.tar.gz &
  wget -N -q --show-progress https://github.com/dftd3/simple-dftd3/archive/refs/tags/v1.3.0.tar.gz &
  wait
  if [ -d "$dftfeDir/src/.git" ]; then
    git -C "$dftfeDir/src" pull
  else
    git clone -b "$branch" "$dftfeRepo" "$dftfeDir/src"
  fi
fi

# unpack <archive> <dir>: extract into $srcDir/<dir> and cd into a fresh build directory
unpack() {
  rm -rf "$srcDir/$2" "$srcDir/tmp"
  mkdir -p "$srcDir/tmp"
  tar xf "$srcDir/$1" -C "$srcDir/tmp"
  mv "$srcDir"/tmp/* "$srcDir/$2"
  rmdir "$srcDir/tmp"
  mkdir -p "$srcDir/$2/build"
  cd "$srcDir/$2/build"
}

install_alglib() {
  unpack alglib-4.07.0.cpp.gpl.tgz alglib
  printf '%s\n' ../src/*.cpp | xargs -P "$nprocs" -n 1 $cxx_compiler $opt_flags -c
  $cxx_compiler -shared -o "$depDir/lib/libAlglib.so" *.o
  cp ../src/*.h "$depDir/include/"
}

install_libxc() {
  unpack libxc-7.1.2.tar.gz libxc
  cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$depDir" -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_C_FLAGS="$opt_flags" \
    -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$opt_flags" \
    -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -DENABLE_FORTRAN=OFF
  cmake --build . -j "$nprocs"
  cmake --install .
}

install_spglib() {
  unpack v2.7.0.tar.gz spglib
  cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$depDir" -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_C_FLAGS="$opt_flags" \
    -DSPGLIB_SHARED_LIBS=ON -DSPGLIB_WITH_TESTS=OFF -DSPGLIB_WITH_Fortran=OFF -DSPGLIB_WITH_Python=OFF
  cmake --build . -j "$nprocs"
  cmake --install .
}

install_libxml2() {
  unpack libxml2-2.15.3.tar.xz libxml2
  CC=$c_compiler CFLAGS="$opt_flags" ../configure --prefix="$depDir" --without-python --enable-shared --disable-static
  make -j "$nprocs"
  make install
}

install_numdiff() {
  unpack numdiff-5.9.0.tar.gz numdiff
  CC=$c_compiler CFLAGS="-O2 -Wno-error=implicit-function-declaration -Wno-error=implicit-int" \
    ../configure --prefix="$depDir" --disable-nls --disable-gmp
  make -j "$nprocs"
  make install
}

install_p4est() {
  unpack p4est-2.8.7.tar.gz p4est
  ../configure --prefix="$depDir" CC=$mpi_c_compiler CXX=$mpi_cxx_compiler FC=$mpi_fortran_compiler F77=$mpi_fortran_compiler \
    CFLAGS="$opt_flags" CPPFLAGS="-DSC_LOG_PRIORITY=SC_LP_ESSENTIAL" \
    --enable-mpi --enable-shared --disable-static --disable-vtk-binary --without-blas --disable-openmp
  make -j "$nprocs"
  make install
}

install_kokkos() {
  unpack 4.7.02.tar.gz kokkos
  cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$depDir" -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_FLAGS="$opt_flags" \
    -DBUILD_SHARED_LIBS=ON -DKokkos_ENABLE_SERIAL=ON
  cmake --build . -j "$nprocs"
  cmake --install .
}

install_boost() {
  unpack boost_1_92_0.tar.bz2 boost
  local buildDir=$PWD
  cd ..
  ./bootstrap.sh --prefix="$depDir" --with-toolset=gcc --without-libraries=python,mpi,graph_parallel
  sed -i "s|using gcc ;|using gcc : : $cxx_compiler ;|" project-config.jam
  ./b2 --build-dir="$buildDir" toolset=gcc cxxstd=17 variant=release link=shared runtime-link=shared \
    threading=multi cxxflags="$opt_flags" -j "$nprocs" -q install
}

install_dealii() {
  unpack dealii-9.8.0.tar.gz dealii
  cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$depDir" \
    -DCMAKE_C_COMPILER=$mpi_c_compiler -DCMAKE_CXX_COMPILER=$mpi_cxx_compiler -DCMAKE_Fortran_COMPILER=$mpi_fortran_compiler \
    -DCMAKE_CXX_STANDARD=17 -DCMAKE_C_FLAGS="$opt_flags $openmp_flag" -DCMAKE_CXX_FLAGS="$opt_flags $openmp_flag" \
    -DDEAL_II_ALLOW_AUTODETECTION=OFF -DDEAL_II_ALLOW_PLATFORM_INTROSPECTION=OFF -DDEAL_II_HAVE_SSE2=ON \
    -DDEAL_II_COMPONENT_EXAMPLES=OFF -DDEAL_II_COMPONENT_DOCUMENTATION=OFF \
    -DDEAL_II_WITH_MPI=ON -DDEAL_II_WITH_64BIT_INDICES=ON -DDEAL_II_WITH_COMPLEX_VALUES=ON \
    -DDEAL_II_WITH_P4EST=ON -DP4EST_DIR="$depDir" \
    -DDEAL_II_WITH_LAPACK=ON -DLAPACK_FOUND=true -DLAPACK_LIBRARIES="$lapackLibs" \
    -DBLAS_FOUND=true -DBLAS_LIBRARIES="$lapackLibs" \
    -DDEAL_II_WITH_KOKKOS=ON -DKOKKOS_DIR="$depDir" \
    -DDEAL_II_WITH_BOOST=ON -DBOOST_DIR="$depDir" -DDEAL_II_FORCE_BUNDLED_BOOST=OFF \
    -DDEAL_II_WITH_ZLIB=ON -DDEAL_II_WITH_TBB=OFF -DDEAL_II_WITH_TASKFLOW=OFF
  cmake --build . -j "$nprocs"
  cmake --install .
}

install_elpa() {
  unpack elpa-2026.02.002.tar.gz elpa
  local variant
  if [ "$elpaWithOpenMP" = ON ]; then
    variant=(--enable-openmp --enable-runtime-threading-support-checks --enable-allow-thread-limiting
             --without-threading-support-check-during-build)
  else
    variant=(--enable-gpu-ccl=nccl --with-nccl-path="$NCCL_ROOT")
  fi
  CC=$mpi_c_compiler CXX=$mpi_cxx_compiler FC=$mpi_fortran_compiler \
  CFLAGS="$opt_flags" CXXFLAGS="$opt_flags" FCFLAGS="$opt_flags -fallow-argument-mismatch" \
  CPPFLAGS="-I$CUDA_MATH_HOME/include -I$NCCL_INCLUDE_DIR" \
  LDFLAGS="-L$CUDA_MATH_HOME/lib64 -L$NCCL_LIB_DIR -Wl,-rpath,$CUDA_MATH_HOME/lib64 -Wl,-rpath,$NCCL_LIB_DIR" \
  SCALAPACK_LDFLAGS="$scalapackLibs -lstdc++ -Wl,-rpath,$libsciDir" \
  SCALAPACK_FCFLAGS="$scalapackLibs -lstdc++" \
  ../configure --prefix="$depDir" --enable-option-checking=fatal \
    --with-mpi=yes --enable-shared --disable-static --disable-silent-rules \
    --enable-c-tests=no --enable-cpp-tests=no \
    --disable-sse-kernels --disable-sse-assembly-kernels \
    --enable-avx-kernels --enable-avx2-kernels --disable-avx512-kernels \
    --enable-nvidia-gpu-kernels --with-NVIDIA-GPU-compute-capability=sm_80 \
    --enable-gpu-streams=nvidia --with-cuda-path="$CUDA_HOME" --with-cuda-sdk-path="$CUDA_HOME" \
    "${variant[@]}"
  make -j "$nprocs"
  rm -rf "$depDir"/include/elpa{,_openmp}-* "$depDir"/lib/libelpa* "$depDir"/lib/pkgconfig/elpa*.pc
  make install
}

install_dftd() {
  unpack v4.2.0.tar.gz dftd4
  unpack v1.3.0.tar.gz dftd3
  for dir in dftd4 dftd3; do
    cd "$srcDir/$dir/build"
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$depDir" -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_Fortran_COMPILER=$fortran_compiler -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_Fortran_FLAGS="$opt_flags" \
      -DBLAS_LIBRARIES="$lapackLibs" -DLAPACK_LIBRARIES="$lapackLibs" \
      -DBUILD_SHARED_LIBS=ON -DWITH_OpenMP=OFF -DCMAKE_PREFIX_PATH="$depDir"
    cmake --build . -j "$nprocs"
    cmake --install .
  done
}

install_dftfe() {
  for complex in OFF ON; do
    if [ $complex = ON ]; then bdir=$dftfeDir/install/complex; else bdir=$dftfeDir/install/real; fi
    cmake -S "$dftfeDir/src" -B "$bdir" \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_CXX_COMPILER=$mpi_cxx_compiler -DCMAKE_CXX_FLAGS="$opt_flags $openmp_flag -I$CUDA_MATH_HOME/include" \
      -DCMAKE_CUDA_HOST_COMPILER=$cxx_compiler -DCMAKE_CUDA_ARCHITECTURES="$device_architectures" \
      -DCMAKE_CUDA_FLAGS="-O2 -I$CRAY_MPICH_DIR/include -I$CUDA_MATH_HOME/include" \
      -DDEAL_II_DIR="$depDir" -DALGLIB_DIR="$depDir" -DLIBXC_DIR="$depDir" -DSPGLIB_DIR="$depDir" \
      -DXML_LIB_DIR="$depDir/lib" -DXML_INCLUDE_DIR="$depDir/include/libxml2" \
      -DCMAKE_PREFIX_PATH="$depDir;$NCCL_ROOT" \
      -DWITH_GPU=ON -DGPU_LANG=cuda -DGPU_VENDOR=nvidia -DWITH_GPU_AWARE_MPI=$withGPUAwareMPI \
      -DWITH_DCCL=$withDCCL -DNCCL_INCLUDE_DIR="$NCCL_INCLUDE_DIR" -DNCCL_LIB_DIR="$NCCL_LIB_DIR" \
      -DWITH_MDI=OFF -DWITH_TORCH=OFF -DWITH_TESTING=$testing \
      -DMINIMAL_COMPILE=$minimalCompile -DHIGHERQUAD_PSP=$withHigherQuadPSP \
      -DUSE_64BIT_INT=$useInt64 -DWITH_COMPLEX=$complex
    cmake --build "$bdir" -j "$nprocs"
  done
}

for pkg in "${stages[@]}"; do
  if [[ ${want[$pkg]} ]]; then
    ( install_$pkg ) 2>&1 | tee "$logDir/$pkg.log"
  fi
done

if [[ $cleanSrc ]]; then
  rm -rf "${srcDir:?}"/*/
fi
