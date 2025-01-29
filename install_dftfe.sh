#!/bin/bash
trap "pkill -9 wget; exit" INT
set -e
export PYTHON=python3

c_compiler=fcc
mpi_c_compiler=mpifcc
c_flags="-Kopenmp,fast -Nclang -fPIC"
export fcc_ENV="-Kopenmp,fast -Nclang -fPIC"

cxx_compiler=FCC
mpi_cxx_compiler=mpiFCC
cxx_flags="-Kopenmp,fast -Nclang -std=c++17 -fPIC"
export FCC_ENV="-Kopenmp,fast -Nclang -std=c++17 -fPIC"

fortran_compiler=frt
mpi_fortran_compiler=mpifrt
fortran_flags="-Kopenmp,fast,SVE -fPIC"

prefix="$PWD"
nprocs=8

#DFT-FE options, all of these have to be set
withHigherQuadPSP=OFF
testing=ON
minimal_compile=ON


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
dcclDir=""
blasLapackFlags="-SSL2BLAMP -SCALAPACK"
scalapackFlags="-SSL2BLAMP -SCALAPACK"

#Paths to pre-compiled dealii dependencies if any
kokkosDir=""
p4estDir=""
boostDir=""

# Installation script for DFT-FE and its dependencies
currentDir=$PWD
cd $prefix
dependencyDir=$prefix/dependencies
dftfeDir=$prefix/dftfe
mkdir -p $dependencyDir
mkdir -p $dftfeDir
mkdir -p $dftfeDir/src
mkdir -p $dftfeDir/install
mkdir -p $dependencyDir/src
mkdir -p $dependencyDir/lib
mkdir -p $dependencyDir/include
mkdir -p $dependencyDir/bin



downloadDependencies=""
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
    wget -N -q --show-progress https://github.com/GNOME/libxml2/archive/refs/tags/v2.13.5.tar.gz &
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
     wget -N -q --show-progress https://raw.githubusercontent.com/spack/spack/0f54995e53d48095a30f1d0203e4f9bdb95e29fa/var/spack/repos/builtin/packages/boost/fujitsu_version_analysis-1.77.patch
     wget -N -q --show-progress https://raw.githubusercontent.com/spack/spack/0f54995e53d48095a30f1d0203e4f9bdb95e29fa/var/spack/repos/builtin/packages/boost/bootstrap-compiler.patch
    fi
    wget -N -q --show-progress https://github.com/dealii/dealii/releases/download/v9.6.2/dealii-9.6.2.tar.gz &
  fi
  if [ -z $elpaDir ]; then
    wget -N -q --show-progress https://elpa.mpcdf.mpg.de/software/tarball-archive/Releases/2024.05.001/elpa-2024.05.001.tar.gz &
  fi
  wait
  cd $dftfeDir
  if [ -z "$( ls -A 'src' )" ]; then
    git clone --branch publicGithubDevelop https://knikhil1995@bitbucket.org/dftfedevelopers/dftfe.git src
  else
    cd src
    git pull
    cd ..
  fi

  
  echo "Download done"
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
    $cxx_compiler $cxx_flags -c *.cpp
    ar rcs libAlglib.a *.o
    mv libAlglib.a $dependencyDir/lib
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
    cmake -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_C_FLAGS="$c_flags" -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_INSTALL_PREFIX=$dependencyDir -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF ..
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
    cmake -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_C_FLAGS="$c_flags" -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_INSTALL_PREFIX=$dependencyDir -DSPGLIB_SHARED_LIBS=OFF ..
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
    tar xzf v2.13.5.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling libxml2"
    cd libxml2-2.13.5
    mkdir -p build && cd build
    ../autogen.sh --prefix=$dependencyDir --without-python
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
      ../configure CC=$mpi_c_compiler CXX=$mpi_cxx_compiler FC=$mpi_fortran_compiler F77=$mpi_fortran_compiler --enable-mpi --enable-shared --disable-vtk-binary --without-blas CPPFLAGS=-DSC_LOG_PRIORITY=SC_LP_ESSENTIAL CFLAGS=-O2 --prefix=$dependencyDir --disable-openmp --enable-static --disable-shared
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
      cmake -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_C_FLAGS="$c_flags" -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_INSTALL_PREFIX=$dependencyDir -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON ..
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
      patch -s -p 1 -i  $currentDir/fujitsu_version_analysis-1.77.patch -d .
      patch -s -p 1 -i  $currentDir/bootstrap-compiler.patch -d .
      CXX=$cxx_compiler CXX_FLAGS="$cxx_flags" ./bootstrap.sh --prefix=$dependencyDir --without-libraries=python --without-icu
      echo "using clang : : $cxx_compiler ;" > user-config.jam
      ./b2 link=static -j$nprocs --disable-icu --user-config=user-config.jam toolset=clang cxxstd=17 variant=release -q install
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
    tar xzf elpa-2024.05.001.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling ELPA"
    cd elpa-2024.05.001
    patch -s -p 1 -i $currentDir/elpa_fujitsu.patch -d .
    mkdir -p build && cd build
    CXX=$mpi_cxx_compiler CC=$mpi_c_compiler FC=$mpi_fortran_compiler CFLAGS="$c_flags" FCFLAGS="$fortran_flags" CXXFLAGS="$cxx_flags" SCALAPACK_FCFLAGS="$blasLapackFlags $scalapackFlags" SCALAPACK_LDFLAGS="$blasLapackFlags $scalapackFlags" ../configure --prefix=$dependencyDir --disable-avx-kernels --disable-avx2-kernels --disable-avx512-kernels --enable-c-tests=no --enable-cpp-tests=no --enable-openmp --enable-option-checking=fatal --disable-sse-kernels --disable-sse-assembly-kernels --with-mpi --enable-runtime-threading-support-checks --enable-allow-thread-limiting --without-threading-support-check-during-build --enable-static --disable-shared --host=aarch64-unknown-linux-gnu --disable-Fortran2008-features --enable-FUGAKU --with-pic
    sed -i 's/\\$wl-soname \\$wl\\$soname/-fuse-ld=ld -Wl,-soname,\\$soname/g' libtool
    sed -i 's/\\$wl--whole-archive\\$convenience \\$wl--no-whole-archive//g' libtool
    make -j$nprocs
    make install
  fi
  elpaDir=$dependencyDir
  echo "ELPA path set to: $elpaDir"
fi

if [[ $installDFTFE ]]; then
  cd $dftfeDir/install
  echo "Compiling DFTFE real executable"
  mkdir -p real && cd real
  cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$mpi_cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_BUILD_TYPE=Release -DDEAL_II_DIR=$dealiiDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=$withDCCL -DWITH_TORCH=OFF -DCMAKE_PREFIX_PATH="$elpaDir;$dcclDir" -DWITH_GPU=OFF  -DWITH_TESTING=$testing -DMINIMAL_COMPILE=$minimal_compile -DHIGHERQUAD_PSP=$withHigherQuadPSP -DWITH_COMPLEX=OFF -DBUILD_SHARED_LIBS=OFF $dftfeDir/src
  make -j$nprocs
  cd $dftfeDir/install
  echo "Compiling DFTFE complex executable"
  mkdir -p complex && cd complex
  cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$mpi_cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_BUILD_TYPE=Release -DDEAL_II_DIR=$dealiiDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=$withDCCL -DWITH_TORCH=OFF -DCMAKE_PREFIX_PATH="$elpaDir;$dcclDir" -DWITH_GPU=OFF -DWITH_TESTING=$testing -DMINIMAL_COMPILE=$minimal_compile -DHIGHERQUAD_PSP=$withHigherQuadPSP -DWITH_COMPLEX=ON -DBUILD_SHARED_LIBS=OFF $dftfeDir/src
  make -j$nprocs
fi


if [[ $cleanSrc ]]; then
  cd $dependencyDir/src
  rm -rf *
fi





