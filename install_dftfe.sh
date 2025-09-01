#!/bin/bash
trap "pkill -9 wget; exit" INT
set -e

#LOAD MODULES
#EXPORT ENVIRONMENTS

c_compiler=gcc
mpi_c_compiler=mpicc
c_flags="-fPIC -O2 -march=native"
cxx_compiler=g++
mpi_cxx_compiler=mpicxx
cxx_flags="-fPIC -O2 -march=native"
fortran_compiler=gfortran
mpi_fortran_compiler=mpifort
fortran_flags="-fPIC -O2 -march=native -fallow-argument-mismatch"
device_compiler=nvcc
device_flags="-arch=sm_80 -O2 -march=native -ccbin=$mpi_cxx_compiler"
device_architectures="80"

prefix="$PWD"
nprocs=2  # default
for arg in "$@"; do
  if [[ "$arg" == --nprocs=* ]]; then
    nprocs="${arg#--nprocs=}"
  fi
done

#DFT-FE options, all of these have to be set
withGPU=ON
gpuLang="cuda"
gpuVendor="nvidia"
withGPUAwareMPI=OFF
withHigherQuadPSP=ON
useInt64=ON
testing=ON
minimal_compile=ON

#Option to link to DCCL library (Only for GPU compilation)
withDCCL=ON

#Paths to pre-compiled dftfe dependencies if any
dealiiDir=""
alglibDir=""
libxcDir=""
spglibDir=""
xmlIncludeDir=""
xmlLibDir=""
elpaDir=""
dftdDir=""
numdiffDir=""
dcclDir="" # SET NCCL PATH
blasLapackFlags=""
scalapackFlags=""

#Paths to pre-compiled dealii dependencies if any
kokkosDir=""
p4estDir=""
boostDir=""

# Parse branch flag
branch="release1.2"

# Installation script for DFT-FE and its dependencies
currentDir=$PWD
cd $prefix
dependencyDir=$prefix/dependencies
dftfeDir="$prefix/dftfe_$branch"
mkdir -p $dependencyDir
mkdir -p $dftfeDir
mkdir -p $dftfeDir/src
mkdir -p $dftfeDir/install
mkdir -p $dependencyDir/src
mkdir -p $dependencyDir/lib
mkdir -p $dependencyDir/include
mkdir -p $dependencyDir/bin

downloadDependencies=""
installBLASLAPACK=""
installScaLAPACK=""
installAlglib=""
installspglib=""
installlibxml2=""
installnumdiff=""
installlibxc=""
installp4est=""
installkokkos=""
installboost=""
installdealii=""
installElpa=""
installDFTFE=""
cleanSrc=""

if [[ "$*" == *"--download"* ]]; then
    downloadDependencies=true
fi

if [[ "$*" == *"--blaslapack"* ]]; then
    installBLASLAPACK=true
fi

if [[ "$*" == *"--scalapack"* ]]; then
    installScaLAPACK=true
fi

if [[ "$*" == *"--alglib"* ]]; then
    installAlglib=true
fi

if [[ "$*" == *"--spglib"* ]]; then
    installspglib=true
fi

if [[ "$*" == *"--libxml2"* ]]; then
    installlibxml2=true
fi

if [[ "$*" == *"--numdiff"* ]]; then
    installnumdiff=true
fi

if [[ "$*" == *"--libxc"* ]]; then
    installlibxc=true
fi

if [[ "$*" == *"--p4est"* ]]; then
    installp4est=true
fi

if [[ "$*" == *"--kokkos"* ]]; then
    installkokkos=true
fi

if [[ "$*" == *"--boost"* ]]; then
    installboost=true
fi

if [[ "$*" == *"--dealii"* ]]; then
    installdealii=true
fi

if [[ "$*" == *"--elpa"* ]]; then
    installElpa=true
fi

if [[ "$*" == *"--dftfe"* ]]; then
    installDFTFE=true
fi

if [[ "$*" == *"--clean-build-files"* ]]; then
    cleanSrc=true
fi

if [[ "$*" == *"--all"* ]]; then
  downloadDependencies=true
  installBLASLAPACK=true
  installScaLAPACK=true
  installAlglib=true
  installspglib=true
  installlibxml2=true
  installnumdiff=true
  installlibxc=true
  installp4est=true
  installkokkos=true
  installboost=true
  installdealii=true
  installElpa=true
  installDFTFE=true
fi

if [[ $downloadDependencies ]]; then
  echo "Downloading required dependencies"
  cd $dependencyDir/src
  if [ -z $alglibDir ]; then
    wget -N -q --show-progress https://www.alglib.net/translator/re/alglib-4.04.0.cpp.gpl.tgz &
  fi
  if [ -z $libxcDir ]; then
    wget -N -q --show-progress https://gitlab.com/libxc/libxc/-/archive/6.2.2/libxc-6.2.2.tar.gz &
  fi
  if [ -z $spglibDir ]; then
    wget -N -q --show-progress https://github.com/spglib/spglib/archive/refs/tags/v2.5.0.tar.gz &
  fi
  if [ -z $numdiffDir ]; then
    wget -N -q --show-progress https://nongnu.askapache.com/numdiff/numdiff-5.9.0.tar.gz &
  fi
  if [ -z $xmlLibDir ]; then
    wget -N -q --show-progress https://download.gnome.org/sources/libxml2/2.13/libxml2-2.13.5.tar.xz &
  fi
  if [ -z $dealiiDir ]; then
    if [ -z $p4estDir ]; then
     wget -N -q --show-progress https://p4est.github.io/release/p4est-2.8.6.tar.gz &
    fi
    if [ -z $kokkosDir ]; then
     wget -N -q --show-progress https://github.com/kokkos/kokkos/archive/refs/tags/4.3.00.tar.gz &
    fi
    if [ -z $boostDir ]; then
     wget -N -q --show-progress https://sourceforge.net/projects/boost/files/boost/1.86.0/boost_1_86_0.tar.bz2 &
    fi
    wget -N -q --show-progress https://github.com/dealii/dealii/releases/download/v9.6.2/dealii-9.6.2.tar.gz &
  fi
  if [ -z $blasLapackFlags ]; then
    wget -N -q --show-progress https://github.com/flame/blis/archive/refs/tags/1.1.tar.gz &
    wget -N -q --show-progress https://github.com/flame/libflame/archive/5.2.0.tar.gz &
  fi
  if [ -z $scalapackFlags ]; then
    wget -N -q --show-progress https://github.com/Reference-ScaLAPACK/scalapack/archive/refs/tags/v2.2.0.tar.gz &
  fi
  if [ -z $elpaDir ]; then
    wget -N -q --show-progress https://elpa.mpcdf.mpg.de/software/tarball-archive/Releases/2025.06.001/elpa-2025.06.001.tar.gz &
  fi
  wait
  cd $dftfeDir
  if [ -z "$( ls -A 'src' )" ]; then
    git clone https://github.com/dftfeDevelopers/install_DFTFE src
  else
    cd src
    git pull
    cd ..
  fi
  echo "Download done"
fi

if [[ $blasLapackFlags ]]; then
  echo "BLAS and LAPACK flags set to: $blasLapackFlags"
else
  if [[ $installBLASLAPACK ]]; then
    cd $dependencyDir/src
    echo "Extracting BLIS"
    tar xzf 1.1.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling BLIS"
    cd blis-1.1
    CC=$c_compiler CXX=$cxx_compiler FC=$fortran_compiler F77=$fortran_compiler ./configure --prefix=$dependencyDir --enable-scalapack-compat --enable-blas --enable-threading=openmp --disable-static --enable-shared auto
    make -j$nprocs
    make install
    echo "BLIS path set to: $dependencyDir"
  fi
  blasLapackFlags="-Wl,-rpath=$dependencyDir/lib -L$dependencyDir/lib -lblis -Wl,--no-as-needed"
  echo "BLAS flags set to: $blasLapackFlags"

  if [[ $installBLASLAPACK ]]; then
    cd $dependencyDir/src
    echo "Extracting libflame"
    tar xzf 5.2.0.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling libflame"
    cd libflame-5.2.0
    CC=$c_compiler CXX=$cxx_compiler FC=$fortran_compiler F77=$fortran_compiler LDFLAGS="$blasLapackFlags" CFLAGS="$c_flags" CPPFLAGS="$c_flags" FFLAGS="$fortran_flags" ./configure --prefix=$dependencyDir --enable-lapack2flame  --enable-max-arg-list-hack --enable-dynamic-build --disable-static-build --enable-verbose-make-output
    make -j$nprocs
    make install
    echo "libflame path set to: $dependencyDir"
  fi
  blasLapackFlags="$blasLapackFlags -lflame"
  echo "BLAS/LAPACK flags set to: $blasLapackFlags"  
fi

if [[ $scalapackFlags ]]; then
  echo "ScaLAPACK flags set to: $scalapackFlags"
else
  if [[ $installScaLAPACK ]]; then
    cd $dependencyDir/src
    echo "Extracting netlib-scalapack"
    tar xzf v2.2.0.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling netlib-scalapack"
    cd scalapack-2.2.0
    rm -rf build
    mkdir -p build && cd build
    cmake -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_Fortran_COMPILER=$mpi_fortran_compiler -DCMAKE_Fortran_FLAGS="$fortran_flags" -DCMAKE_C_COMPILER=$mpi_c_compiler -DCMAKE_C_FLAGS="$c_flags -Wno-error=implicit-function-declaration" -DUSE_OPTIMIZED_LAPACK_BLAS=ON -DUSE_OPTIMIZED_LAPACK_BLAS=ON -DBLAS_LIBRARIES="$blasLapackFlags" -DLAPACK_FOUND=true -DLAPACK_LIBRARIES="$blasLapackFlags" -DCMAKE_INSTALL_PREFIX=$dependencyDir ..
    cmake --build . -j$nprocs
    cmake --install .
    echo "ScaLAPACK path set to: $dependencyDir"
  fi
  scalapackFlags="-L$dependencyDir/lib -lscalapack"
  echo "ScaLAPACK flags set to: $scalapackFlags"
fi

if [[ $alglibDir ]]; then
  echo "Alglib path set to: $alglibDir"
else
  if [[ $installAlglib ]]; then
    cd $dependencyDir/src
    echo "Extracting alglib"
    tar xzf alglib-4.04.0.cpp.gpl.tgz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling Alglib"
    cd alglib-cpp/src
    $cxx_compiler -o libAlglib.so -shared $cxx_flags *.cpp
    mv libAlglib.so $dependencyDir/lib
    cp *.h $dependencyDir/include
  fi
  alglibDir=$dependencyDir
  echo "Alglib path set to: $alglibDir"
fi

if [[ $libxcDir ]]; then
  echo "libxc path set to: $libxcDir"
else
  if [[ $installlibxc ]]; then
    cd $dependencyDir/src
    echo "Extracting libxc"
    tar xzf libxc-6.2.2.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling libxc"
    cd libxc-6.2.2
    mkdir -p build && cd build
    cmake -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_C_FLAGS="$c_flags" -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_INSTALL_PREFIX=$dependencyDir -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF ..
    cmake --build . -j $nprocs
    cmake --install .
  fi
  libxcDir=$dependencyDir
  echo "libxc path set to: $libxcDir"
fi

if [[ $spglibDir ]]; then
  echo "spglib path set to: $spglibDir"
else
  if [[ $installspglib ]]; then
    cd $dependencyDir/src
    echo "Extracting spglib"
    tar xzf v2.5.0.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling spglib"
    cd spglib-2.5.0
    mkdir -p build && cd build
    cmake -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_C_FLAGS="$c_flags" -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_INSTALL_PREFIX=$dependencyDir -DBUILD_SHARED_LIBS=ON ..
    cmake --build . -j$nprocs
    cmake --install .
  fi
  spglibDir=$dependencyDir
  echo "spglib path set to: $spglibDir"
fi

if [[ $xmlLibDir ]]; then
  echo "libxml2 library path set to: $xmlLibDir"
  echo "libxml2 include path set to: $xmlIncludeDir"
else
  if [[ $installlibxml2 ]]; then
    cd $dependencyDir/src
    echo "Extracting libxml2"
    tar xf libxml2-2.13.5.tar.xz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling libxml2"
    cd libxml2-2.13.5
    mkdir -p build && cd build
    .././configure --prefix=$dependencyDir --without-python
    make -j$nprocs
    make install
  fi
  xmlLibDir=$dependencyDir/lib
  xmlIncludeDir=$dependencyDir/include/libxml2
  echo "libxml2 library path set to: $xmlLibDir"
  echo "libxml2 include path set to: $xmlIncludeDir"
fi

if [[ $numdiffDir ]]; then
  echo "numdiff path set to: $numdiffDir"
else
  if [[ $installnumdiff ]]; then
    cd $dependencyDir/src
    echo "Extracting numdiff"
    tar xzf numdiff-5.9.0.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling numdiff"
    cd numdiff-5.9.0
    mkdir -p build && cd build
    ../configure --prefix=$dependencyDir --disable-nls --disable-gmp
    make -j$nprocs 
    make install
  fi
  numdiffDir=$dependencyDir
  echo "numdiff path set to: $numdiffDir"
fi

if [[ $dealiiDir ]]; then
  echo "dealii path set to: $dealiiDir"
else

  if [[ $p4estDir ]]; then
    echo "p4est path set to: $p4estDir"
  else
    if [[ $installp4est ]]; then
      cd $dependencyDir/src
      echo "Extracting spglib"
      tar xzf p4est-2.8.6.tar.gz --checkpoint=.100
      echo "Extraction done"
      cd p4est-2.8.6
      mkdir -p build && cd build
      ../configure CC=$mpi_c_compiler CXX=$mpi_cxx_compiler FC=$mpi_fortran_compiler F77=$mpi_fortran_compiler --enable-mpi --enable-shared --disable-vtk-binary --without-blas CPPFLAGS=-DSC_LOG_PRIORITY=SC_LP_ESSENTIAL CFLAGS=-O2 --prefix=$dependencyDir --disable-openmp --disable-static
      make -j$nprocs
      make install
    fi
    p4estDir=$dependencyDir
    echo "p4est path set to: $p4estDir"
  fi

  if [[ $kokkosDir ]]; then
    echo "kokkos path set to: $kokkosDir"
  else
    if [[ $installkokkos ]]; then
      cd $dependencyDir/src
      echo "Extracting kokkos"
      tar xzf 4.3.00.tar.gz --checkpoint=.100
      echo "Extraction done"
      cd kokkos-4.3.00
      mkdir -p build && cd build
      cmake -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_C_FLAGS="$c_flags" -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_INSTALL_PREFIX=$dependencyDir -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF ..
      cmake --build . -j$nprocs
      cmake --install .
    fi
    kokkosDir=$dependencyDir
    echo "kokkos path set to: $kokkosDir"
  fi

  if [[ $boostDir ]]; then
    echo "boost path set to: $boostDir"
  else
    if [[ $installboost ]]; then
      cd $dependencyDir/src
      echo "Extracting boost"
      tar xf boost_1_86_0.tar.bz2 --checkpoint=.100
      echo "Extraction done"
      cd boost_1_86_0
      ./bootstrap.sh --prefix=$dependencyDir --without-libraries=python 
      ./b2 link=shared runtime-link=shared -j$nprocs -q install
    fi
    boostDir=$dependencyDir
    echo "boost path set to: $boostDir"
  fi

  if [[ $installdealii ]]; then
    cd $dependencyDir/src
    echo "Extracting dealii"
    tar xzf dealii-9.6.2.tar.gz  --checkpoint=.100
    echo "Extraction done"
    cd dealii-9.6.2
    mkdir -p build && cd build
    cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_C_FLAGS="$c_flags" -DDEAL_II_ALLOW_PLATFORM_INTROSPECTION=OFF -DDEAL_II_FORCE_BUNDLED_BOOST=OFF -DDEAL_II_WITH_TASKFLOW=OFF -DKOKKOS_DIR=$kokkosDir -DBOOST_DIR=$boostDir -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=$mpi_c_compiler -DCMAKE_CXX_COMPILER=$mpi_cxx_compiler -DCMAKE_Fortran_COMPILER=$mpi_fortran_compiler -DDEAL_II_WITH_TBB=OFF -DDEAL_II_COMPONENT_EXAMPLES=OFF -DDEAL_II_WITH_MPI=ON -DDEAL_II_WITH_64BIT_INDICES=ON -DP4EST_DIR=$dependencyDir -DDEAL_II_WITH_LAPACK=ON -DLAPACK_FOUND=true -DLAPACK_LIBRARIES="$blasLapackFlags" -DCMAKE_INSTALL_PREFIX=$dependencyDir ..
    cmake --build . -j$nprocs
    cmake --install .
  fi
  dealiiDir=$dependencyDir
  echo "dealii path set to: $dependencyDir"
fi

if [[ $elpaDir ]]; then
  echo "ELPA path set to: $elpaDir"
else
  if [[ $installElpa ]]; then
    cd $dependencyDir/src
    echo "Extracting ELPA"
    tar xzf elpa-2025.06.001.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling ELPA"
    cd elpa-2025.06.001
    mkdir -p build && cd build
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$dependencyDir/lib
    export LIBRARY_PATH=$LIBRARY_PATH:$dependencyDir/lib
    CC=$mpi_c_compiler FC=$mpi_fortran_compiler CFLAGS="$c_flags" FCFLAGS="$fortran_flags" SCALAPACK_FCFLAGS="$blasLapackFlags $scalapackFlags" SCALAPACK_LDFLAGS="$blasLapackFlags $scalapackFlags -lstdc++" ../configure --prefix=$dependencyDir --enable-avx-kernels --enable-avx2-kernels --disable-avx512-kernels --enable-c-tests=no --enable-cpp-tests=no --enable-openmp --enable-option-checking=fatal --disable-sse-kernels --disable-sse-assembly-kernels --with-mpi --enable-runtime-threading-support-checks --enable-allow-thread-limiting --without-threading-support-check-during-build --disable-static --enable-shared --enable-nvidia-gpu-kernels --enable-gpu-streams=nvidia --with-NVIDIA-GPU-compute-capability=sm_80 --with-cuda-path=$CUDA_HOME --with-cuda-sdk-path=$CUDA_HOME 
    make VERBOSE=1 -j$nprocs
    make install
  fi
  elpaDir=$dependencyDir
  echo "ELPA path set to: $elpaDir"
fi

if [[ $installDFTFE ]]; then
  cd $dftfeDir/install
  echo "Compiling DFTFE real executable"
  mkdir -p real && cd real
  cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$mpi_cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_BUILD_TYPE=Release -DDEAL_II_DIR=$dealiiDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=$withDCCL -DWITH_TORCH=OFF -DCMAKE_PREFIX_PATH="$elpaDir;$dcclDir" -DWITH_GPU=$withGPU -DGPU_LANG=$gpuLang -DGPU_VENDOR=$gpuVendor -DWITH_GPU_AWARE_MPI=$withGPUAwareMPI -DCMAKE_HIP_FLAGS="$device_flags" -DCMAKE_CUDA_FLAGS="$device_flags" -DCMAKE_CUDA_ARCHITECTURES="$device_architectures" -DCMAKE_HIP_ARCHITECTURES=$device_architectures -DWITH_TESTING=$testing -DMINIMAL_COMPILE=$minimal_compile -DHIGHERQUAD_PSP=$withHigherQuadPSP -DUSE_64BIT_INT=$useInt64 -DWITH_COMPLEX=OFF $dftfeDir/src
  make -j$nprocs

  cd $dftfeDir/install
  echo "Compiling DFTFE complex executable"
  mkdir -p complex && cd complex
  cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$mpi_cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_BUILD_TYPE=Release -DDEAL_II_DIR=$dealiiDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=$withDCCL -DWITH_TORCH=OFF -DCMAKE_PREFIX_PATH="$elpaDir;$dcclDir" -DWITH_GPU=$withGPU -DGPU_LANG=$gpuLang -DGPU_VENDOR=$gpuVendor -DWITH_GPU_AWARE_MPI=$withGPUAwareMPI -DCMAKE_HIP_FLAGS="$device_flags" -DCMAKE_CUDA_FLAGS="$device_flags" -DCMAKE_CUDA_ARCHITECTURES="$device_architectures" -DCMAKE_HIP_ARCHITECTURES=$device_architectures -DWITH_TESTING=$testing -DMINIMAL_COMPILE=$minimal_compile -DHIGHERQUAD_PSP=$withHigherQuadPSP -DUSE_64BIT_INT=$useInt64 -DWITH_COMPLEX=ON $dftfeDir/src
  make -j$nprocs
fi

if [[ $cleanSrc ]]; then
  cd $dependencyDir/src
  rm -rf *
fi
