#!/bin/bash
trap "pkill -9 wget; exit" INT
set -e

#LOAD MODULES
#EXPORT ENVIRONMENTS

c_compiler=gcc
mpi_c_compiler=mpicc
c_flags="-fPIC -O2 -march=native -fopenmp"
cxx_compiler=g++
mpi_cxx_compiler=mpicxx
cxx_flags="-fPIC -O2 -march=native -fopenmp"
fortran_compiler=gfortran
mpi_fortran_compiler=mpifort
fortran_flags="-fPIC -O2 -march=native -fallow-argument-mismatch -fopenmp"
device_compiler=nvcc
device_flags="-arch=sm_70 -O2 -march=native -ccbin=$mpi_cxx_compiler"
device_architectures="70"

prefix="$PWD"
nprocs=16  # default
for arg in "$@"; do
  if [[ "$arg" == --nprocs=* ]]; then
    nprocs="${arg#--nprocs=}"
  fi
done

#DFT-FE options, all of these have to be set
withGPU=OFF
gpuLang="cuda"
gpuVendor="nvidia"
withGPUAwareMPI=OFF
withHigherQuadPSP=ON
useInt64=ON
testing=ON
minimal_compile=ON

#Option to link to DCCL library (Only for GPU compilation)
withDCCL=OFF

#Paths to pre-compiled dftfe dependencies if any
dealiiRealDir=""
dealiiComplexDir=""
alglibDir=""
libxcDir=""
spglibDir=""
xmlIncludeDir="/usr/include/libxml2"
xmlLibDir="/usr/lib64"
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
slepcRealDir=""
petscRealDir=""
slepcComplexDir=""
petscComplexDir=""

# Parse branch flag
branch="release1.2"
for arg in "$@"; do
  if [[ "$arg" == --branch=* ]]; then
    branch="${arg#--branch=}"
  fi
done

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
mkdir -p $dependencyDir/install

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
installslepc=""
installpetsc=""
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

if [[ "$*" == *"--dftd"* ]]; then
    installdftd=true
fi

if [[ "$*" == *"--kokkos"* ]]; then
    installkokkos=true
fi

if [[ "$*" == *"--boost"* ]]; then
    installboost=true
fi

if [[ "$*" == *"--slepc"* ]]; then
    installslepc=true
fi

if [[ "$*" == *"--petsc"* ]]; then
    installpetsc=true
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
  installdftd=true
  installkokkos=true
  installboost=true
  installslepc=true
  installpetsc=true
  installdealii=true
  installElpa=true
  installDFTFE=true
fi

if [[ $downloadDependencies ]]; then
  echo "Downloading required dependencies"
  cd $dependencyDir/src
  if [ -z $alglibDir ]; then
    wget -N -q --show-progress https://www.alglib.net/translator/re/alglib-4.06.0.cpp.gpl.tgz &
  fi
  if [ -z $libxcDir ]; then
    wget -N -q --show-progress https://gitlab.com/libxc/libxc/-/archive/7.0.0/libxc-7.0.0.tar.gz &
  fi
  if [ -z $spglibDir ]; then
    wget -N -q --show-progress https://github.com/spglib/spglib/archive/refs/tags/v2.6.0.tar.gz &
  fi
  if [ -z $numdiffDir ]; then
    wget -N -q --show-progress https://nongnu.askapache.com/numdiff/numdiff-5.9.0.tar.gz &
  fi
  if [ -z $xmlLibDir ]; then
    wget -N -q --show-progress https://github.com/GNOME/libxml2/archive/refs/tags/v2.13.5.tar.gz &
  fi
  if [ -z $dftdDir ]; then
    wget -N -q --show-progress https://github.com/dftd3/simple-dftd3/archive/refs/tags/v1.2.1.tar.gz &
    wget -N -q --show-progress https://github.com/dftd4/dftd4/archive/refs/tags/v3.7.0.tar.gz &
  fi
  if [ -z $dealiiRealDir ]; then
    if [ -z $p4estDir ]; then
     wget -N -q --show-progress https://p4est.github.io/release/p4est-2.8.7.tar.gz &
    fi
    if [ -z $kokkosDir ]; then
     wget -N -q --show-progress https://github.com/kokkos/kokkos/archive/refs/tags/4.3.00.tar.gz &
    fi
    if [ -z $boostDir ]; then
     wget -N -q --show-progress https://sourceforge.net/projects/boost/files/boost/1.86.0/boost_1_86_0.tar.bz2 &
    fi
    if [ -z $petscRealDir ]; then
     wget -N -q --show-progress https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-3.24.1.tar.gz &
    fi
    if [ -z $slepcRealDir ]; then
     wget -N -q --show-progress https://slepc.upv.es/download/distrib/slepc-3.24.0.tar.gz &
    fi
    wget -N -q --show-progress https://github.com/dealii/dealii/releases/download/v9.7.1/dealii-9.7.1.tar.gz &
  fi
  if [ -z "$blasLapackFlags" ]; then
    wget -N -q --show-progress https://github.com/flame/blis/archive/refs/tags/2.0.tar.gz &
    wget -N -q --show-progress https://github.com/flame/libflame/archive/5.2.0.tar.gz &
  fi
  if [ -z "$scalapackFlags" ]; then
    wget -N -q --show-progress https://github.com/Reference-ScaLAPACK/scalapack/archive/refs/tags/v2.2.2.tar.gz &
  fi
  if [ -z $elpaDir ]; then
    wget -N -q --show-progress https://elpa.mpcdf.mpg.de/software/tarball-archive/Releases/2025.06.001/elpa-2025.06.001.tar.gz &
  fi
  wait
  cd $dftfeDir
  if [ -z "$( ls -A 'src' )" ]; then
    git clone --branch "$branch" https://knikhil1995@bitbucket.org/dftfedevelopers/dftfe.git src
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
    CC=$c_compiler CXX=$cxx_compiler FC=$fortran_compiler F77=$fortran_compiler ./configure --prefix=$dependencyDir/install/linalg --enable-scalapack-compat --enable-blas --enable-threading=openmp --disable-static --enable-shared auto
    make -j$nprocs
    make install
    echo "BLIS path set to: $dependencyDir/install/linalg"
  fi
  blasLapackFlags="-Wl,-rpath=$dependencyDir/install/linalg/lib -L$dependencyDir/install/linalg/lib -lblis -Wl,--no-as-needed"
  echo "BLAS flags set to: $blasLapackFlags"

  if [[ $installBLASLAPACK ]]; then
    cd $dependencyDir/src
    echo "Extracting libflame"
    tar xzf 5.2.0.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling libflame"
    cd libflame-5.2.0
    CC=$c_compiler CXX=$cxx_compiler FC=$fortran_compiler F77=$fortran_compiler LDFLAGS="$blasLapackFlags" ./configure --prefix=$dependencyDir/install/linalg --enable-lapack2flame --enable-multithreading=openmp --enable-max-arg-list-hack --enable-dynamic-build --disable-static-build --enable-verbose-make-output
    make -j$nprocs
    make install
    echo "libflame path set to: $dependencyDir/install/linalg"
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
    tar xzf v2.2.2.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling netlib-scalapack"
    cd scalapack-2.2.2
    rm -rf build
    mkdir -p build && cd build
    cmake -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_Fortran_COMPILER=$mpi_fortran_compiler -DCMAKE_Fortran_FLAGS="$fortran_flags" -DCMAKE_C_COMPILER=$mpi_c_compiler -DCMAKE_C_FLAGS="$c_flags -Wno-error=implicit-function-declaration" -DUSE_OPTIMIZED_LAPACK_BLAS=ON -DUSE_OPTIMIZED_LAPACK_BLAS=ON -DBLAS_LIBRARIES="$blasLapackFlags" -DLAPACK_FOUND=true -DLAPACK_LIBRARIES="$blasLapackFlags" -DCMAKE_INSTALL_PREFIX=$dependencyDir/install/linalg ..
    cmake --build . -j$nprocs
    cmake --install .
    echo "ScaLAPACK path set to: $dependencyDir/install/linalg"
  fi
  scalapackFlags="-L$dependencyDir/install/linalg/lib -lscalapack -Wl,-rpath,$dependencyDir/install/linalg/lib"
  echo "ScaLAPACK flags set to: $scalapackFlags"
fi

if [[ $alglibDir ]]; then
  echo "Alglib path set to: $alglibDir"
else
  alglibDir=$dependencyDir/install/alglib
  if [[ $installAlglib ]]; then
    mkdir -p $alglibDir
    mkdir -p $alglibDir/lib
    mkdir -p $alglibDir/include
    cd $dependencyDir/src
    echo "Extracting alglib"
    tar xzf alglib-4.06.0.cpp.gpl.tgz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling Alglib"
    cd alglib-cpp/src
    $cxx_compiler -o libAlglib.so -shared $cxx_flags *.cpp
    mv libAlglib.so $alglibDir/lib
    cp *.h $alglibDir/include
  fi
  echo "Alglib path set to: $alglibDir"
fi

if [[ $libxcDir ]]; then
  echo "libxc path set to: $libxcDir"
else
  libxcDir=$dependencyDir/install/libxc
  if [[ $installlibxc ]]; then
    cd $dependencyDir/src
    echo "Extracting libxc"
    tar xzf libxc-7.0.0.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling libxc"
    cd libxc-7.0.0
    mkdir -p build && cd build
    cmake -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_C_FLAGS="$c_flags" -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_INSTALL_PREFIX=$libxcDir -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF ..
    cmake --build . -j $nprocs
    cmake --install .
  fi
  echo "libxc path set to: $libxcDir"
fi

if [[ $spglibDir ]]; then
  echo "spglib path set to: $spglibDir"
else
  spglibDir=$dependencyDir/install/spglib
  if [[ $installspglib ]]; then
    cd $dependencyDir/src
    echo "Extracting spglib"
    tar xzf v2.6.0.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling spglib"
    cd spglib-2.6.0
    mkdir -p build && cd build
    cmake -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_C_FLAGS="$c_flags" -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_INSTALL_PREFIX=$spglibDir -DBUILD_SHARED_LIBS=ON ..
    cmake --build . -j$nprocs
    cmake --install .
  fi
  echo "spglib path set to: $spglibDir"
fi

if [[ $xmlLibDir ]]; then
  echo "libxml2 library path set to: $xmlLibDir"
  echo "libxml2 include path set to: $xmlIncludeDir"
else
  xmlLibDir=$dependencyDir/install/libxml/lib
  xmlIncludeDir=$dependencyDir/install/libxml/include/libxml2
  if [[ $installlibxml2 ]]; then
    cd $dependencyDir/src
    echo "Extracting libxml2"
    tar xzf v2.13.5.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling libxml2"
    cd libxml2-2.13.5
    mkdir -p build && cd build
    CC=$c_compiler CXX=$cxx_compiler FC=$fortran_compiler ../autogen.sh --prefix=$dependencyDir/install/libxml --without-python
    make -j$nprocs
    make install
  fi
  echo "libxml2 library path set to: $xmlLibDir"
  echo "libxml2 include path set to: $xmlIncludeDir"
fi

if [[ $dftdDir ]]; then
  echo "dftd path set to: $dftdDir"
else
  dftdDir=$dependencyDir/install/dftd
  if [[ $installdftd ]]; then
    cd $dependencyDir/src
    echo "Extracting dftd"
    tar xzf v1.2.1.tar.gz --checkpoint=.100
    tar xzf v3.7.0.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling dftd"
    cd dftd4-3.7.0
    mkdir -p build && cd build
    cmake -DCMAKE_Fortran_COMPILER=$fortran_compiler -DCMAKE_C_COMPILER=$c_compiler -DBLAS_LIBRARIES="$blasLapackFlags" -DLAPACK_LIBRARIES="$blasLapackFlags" -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=$dftdDir -DWITH_OpenMP=OFF ..
    cmake --build . -j $nprocs
    cmake --install .
    cd $dependencyDir/src
    cd simple-dftd3-1.2.1
    mkdir -p build && cd build
    cmake -DCMAKE_Fortran_COMPILER=$fortran_compiler -DCMAKE_C_COMPILER=$c_compiler -DBLAS_LIBRARIES="$blasLapackFlags" -DLAPACK_LIBRARIES="$blasLapackFlags" -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=$dftdDir -DWITH_OpenMP=OFF ..
    cmake --build . -j $nprocs
    cmake --install .
  fi
  echo "dftd path set to: $dftdDir"
fi

if [[ $numdiffDir ]]; then
  echo "numdiff path set to: $numdiffDir"
else
  numdiffDir=$dependencyDir/install/numdiff
  if [[ $installnumdiff ]]; then
    cd $dependencyDir/src
    echo "Extracting numdiff"
    tar xzf numdiff-5.9.0.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling numdiff"
    cd numdiff-5.9.0
    mkdir -p build && cd build
    FC=$fortran_compiler CC=$c_compiler CXX=$cxx_compiler ../configure --prefix=$numdiffDir --disable-nls --disable-gmp
    make -j$nprocs 
    make install
  fi
  echo "numdiff path set to: $numdiffDir"
fi

if [[ $dealiiDir ]]; then
  echo "dealii path set to: $dealiiDir"
else

  if [[ $p4estDir ]]; then
    echo "p4est path set to: $p4estDir"
  else
    p4estDir=$dependencyDir/install/p4est
    if [[ $installp4est ]]; then
      cd $dependencyDir/src
      echo "Extracting p4est"
      tar xzf p4est-2.8.7.tar.gz --checkpoint=.100
      echo "Extraction done"
      cd p4est-2.8.7
      mkdir -p build && cd build
      ../configure CC=$mpi_c_compiler CXX=$mpi_cxx_compiler FC=$mpi_fortran_compiler F77=$mpi_fortran_compiler --enable-mpi --enable-shared --disable-vtk-binary --without-blas CPPFLAGS=-DSC_LOG_PRIORITY=SC_LP_ESSENTIAL CFLAGS=-O2 --prefix=$p4estDir --disable-openmp --disable-static
      make -j$nprocs
      make install
    fi
    echo "p4est path set to: $p4estDir"
  fi

  if [[ $kokkosDir ]]; then
    echo "kokkos path set to: $kokkosDir"
  else
    kokkosDir=$dependencyDir/install/kokkos
    if [[ $installkokkos ]]; then
      cd $dependencyDir/src
      echo "Extracting kokkos"
      tar xzf 4.3.00.tar.gz --checkpoint=.100
      echo "Extraction done"
      cd kokkos-4.3.00
      mkdir -p build && cd build
      cmake -DCMAKE_C_COMPILER=$c_compiler -DCMAKE_C_FLAGS="$c_flags" -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_INSTALL_PREFIX=$kokkosDir -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF ..
      cmake --build . -j$nprocs
      cmake --install .
    fi
    echo "kokkos path set to: $kokkosDir"
  fi

  if [[ $boostDir ]]; then
    echo "boost path set to: $boostDir"
  else
    boostDir=$dependencyDir/install/boost
    if [[ $installboost ]]; then
      cd $dependencyDir/src
      echo "Extracting boost"
      tar xf boost_1_86_0.tar.bz2 --checkpoint=.100
      echo "Extraction done"
      cd boost_1_86_0
      ./bootstrap.sh --prefix=$boostDir --without-libraries=python 
      ./b2 cxxstd=17 variant=release pch=off --disable-icu  link=shared runtime-link=shared -j$nprocs -q install
    fi
    echo "boost path set to: $boostDir"
  fi

  if [[ $petscRealDir ]]; then
    echo "petsc real path set to: $petscRealDir"
  else
    petscRealDir=$dependencyDir/install/petscReal
    if [[ $installpetsc ]]; then
      cd $dependencyDir/src
      echo "Extracting petsc"
      tar xzf petsc-3.24.1.tar.gz --checkpoint=.100
      echo "Extraction done"
      mv petsc-3.24.1 petscReal
      cd petscReal
      ./configure --prefix=$petscRealDir --with-debugging=no --with-64-bit-indices=true --with-cc=$mpi_c_compiler --with-cxx=$mpi_cxx_compiler --with-fc=$mpi_fortran_compiler --with-blas-lapack-lib="$blasLapackFlags $scalapackFlags" CFLAGS="$c_flags" CXXFLAGS="$cxx_flags" FFLAGS="$fortran_flags"
      make PETSC_DIR=$petscRealDir PETSC_ARCH=arch-linux-c-opt all
      make PETSC_DIR=$petscRealDir PETSC_ARCH=arch-linux-c-opt install
    fi
    echo "petsc real path set to: $petscRealDir"
  fi

  if [[ $petscComplexDir ]]; then
    echo "petsc complex path set to: $petscComplexDir"
  else
    petscComplexDir=$dependencyDir/install/petscComplex
    if [[ $installpetsc ]]; then
      cd $dependencyDir/src
      echo "Extracting petsc"
      tar xzf petsc-3.24.1.tar.gz --checkpoint=.100
      echo "Extraction done"
      mv petsc-3.24.1 petscComplex
      cd petscComplex
      ./configure --prefix=$petscComplexDir --with-debugging=no --with-64-bit-indices=true --with-cc=$mpi_c_compiler --with-cxx=$mpi_cxx_compiler --with-fc=$mpi_fortran_compiler --with-scalar-type=complex --with-blas-lapack-lib="$blasLapackFlags $scalapackFlags" CFLAGS="$c_flags" CXXFLAGS="$cxx_flags" FFLAGS="$fortran_flags"
      make PETSC_DIR=$petscComplexDir PETSC_ARCH=arch-linux-c-opt all
      make PETSC_DIR=$petscComplexDir PETSC_ARCH=arch-linux-c-opt install
    fi
    echo "petsc complex path set to: $petscComplexDir"
  fi

  if [[ $slepcRealDir ]]; then
    echo "slepc real path set to: $slepcRealDir"
  else
    slepcRealDir=$dependencyDir/install/slepcReal
    if [[ $installslepc ]]; then
      cd $dependencyDir/src
      echo "Extracting slepc"
      tar xzf slepc-3.24.0.tar.gz --checkpoint=.100
      echo "Extraction done"
      mv slepc-3.24.0 slepcReal
      cd slepcReal
      PETSC_DIR=$petscRealDir ./configure --prefix=$slepcRealDir
      make
      make install
    fi
    echo "slepc real path set to: $slepcRealDir"
  fi

  if [[ $slepcComplexDir ]]; then
    echo "slepc complex path set to: $slepcComplexDir"
  else
    slepcComplexDir=$dependencyDir/install/slepcComplex
    if [[ $installslepc ]]; then
      cd $dependencyDir/src
      echo "Extracting slepc"
      tar xzf slepc-3.24.0.tar.gz --checkpoint=.100
      echo "Extraction done"
      mv slepc-3.24.0 slepcComplex
      cd slepcComplex
      PETSC_DIR=$petscRealDir ./configure --prefix=$slepcComplexDir
      make
      make install
    fi
    echo "slepc complex path set to: $slepcComplexDir"
  fi

  dealiiRealDir=$dependencyDir/install/dealiiReal
  dealiiComplexDir=$dependencyDir/install/dealiiComplex
 if [[ $installdealii ]]; then
    cd $dependencyDir/src
    echo "Extracting dealii"
    tar xzf dealii-9.7.1.tar.gz  --checkpoint=.100
    echo "Extraction done"
    cd dealii-9.7.1
    mkdir -p buildReal && cd buildReal
    cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_FLAGS="$cxx_flags -std=c++17" -DCMAKE_C_FLAGS="$c_flags" -DDEAL_II_ALLOW_PLATFORM_INTROSPECTION=OFF -DDEAL_II_FORCE_BUNDLED_BOOST=OFF -DDEAL_II_WITH_TASKFLOW=OFF -DKOKKOS_DIR=$kokkosDir -DBOOST_DIR=$boostDir -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=$mpi_c_compiler -DCMAKE_CXX_COMPILER=$mpi_cxx_compiler -DCMAKE_Fortran_COMPILER=$mpi_fortran_compiler -DDEAL_II_WITH_TBB=OFF -DDEAL_II_COMPONENT_EXAMPLES=OFF -DDEAL_II_WITH_MPI=ON -DDEAL_II_WITH_64BIT_INDICES=ON -DP4EST_DIR=$p4estDir -DDEAL_II_WITH_LAPACK=ON -DDEAL_II_WITH_PETSC=ON -DPETSC_DIR=$petscRealDir -DDEAL_II_WITH_SLEPC=ON -DSLEPC_DIR=$slepcRealDir -DDEAL_II_WITH_COMPLEX_VALUES=ON -DCMAKE_INSTALL_PREFIX=$dealiiRealDir ..
    cmake --build . -j$nprocs
    cmake --install .
    cd $dependencyDir/src
    cd dealii-9.7.1
    mkdir -p buildComplex && cd buildComplex
    cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_FLAGS="$cxx_flags -std=c++17" -DCMAKE_C_FLAGS="$c_flags" -DDEAL_II_ALLOW_PLATFORM_INTROSPECTION=OFF -DDEAL_II_FORCE_BUNDLED_BOOST=OFF -DDEAL_II_WITH_TASKFLOW=OFF -DKOKKOS_DIR=$kokkosDir -DBOOST_DIR=$boostDir -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=$mpi_c_compiler -DCMAKE_CXX_COMPILER=$mpi_cxx_compiler -DCMAKE_Fortran_COMPILER=$mpi_fortran_compiler -DDEAL_II_WITH_TBB=OFF -DDEAL_II_COMPONENT_EXAMPLES=OFF -DDEAL_II_WITH_MPI=ON -DDEAL_II_WITH_64BIT_INDICES=ON -DP4EST_DIR=$p4estDir -DDEAL_II_WITH_LAPACK=ON -DDEAL_II_WITH_PETSC=ON -DPETSC_DIR=$petscComplexDir -DDEAL_II_WITH_SLEPC=ON -DSLEPC_DIR=$slepcComplexDir -DDEAL_II_WITH_COMPLEX_VALUES=ON -DCMAKE_INSTALL_PREFIX=$dealiiComplexDir ..
    cmake --build . -j$nprocs
    cmake --install .
  fi
  echo "dealii with real slepc/petsc path set to: $dealiiRealDir"
  echo "dealii with complex slepc/petsc path set to: $dealiiComplexDir"
fi

if [[ $elpaDir ]]; then
  echo "ELPA path set to: $elpaDir"
else
  elpaDir=$dependencyDir/install/elpa
  if [[ $installElpa ]]; then
    cd $dependencyDir/src
    echo "Extracting ELPA"
    tar xzf elpa-2025.06.001.tar.gz --checkpoint=.100
    echo "Extraction done"
    echo "Compiling ELPA"
    cd elpa-2025.06.001
    mkdir -p build && cd build
    CC=$mpi_c_compiler FC=$mpi_fortran_compiler CXX=$mpi_cxx_compiler CFLAGS="$c_flags" FCFLAGS="$fortran_flags" CXX_FLAGS="$cxx_flags" SCALAPACK_FCFLAGS="$blasLapackFlags $scalapackFlags" SCALAPACK_LDFLAGS="$blasLapackFlags $scalapackFlags -lstdc++" ../configure --prefix=$elpaDir --enable-avx-kernels --enable-avx2-kernels --enable-avx512-kernels --enable-c-tests=no --enable-cpp-tests=no --enable-option-checking=fatal --enable-sse-kernels --enable-sse-assembly-kernels --with-mpi --disable-static --enable-shared --disable-silent-rules --enable-openmp
    make -j$nprocs
    make install
  fi
  echo "ELPA path set to: $elpaDir"
fi

if [[ $installDFTFE ]]; then
  cd $dftfeDir/install
  echo "Compiling DFTFE real executable"
  mkdir -p real && cd real
  cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$mpi_cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_BUILD_TYPE=Release -DDEAL_II_DIR=$dealiiRealDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=$withDCCL -DWITH_TORCH=OFF -DCMAKE_PREFIX_PATH="$elpaDir;$dcclDir;$numdiffDir;$dftdDir" -DWITH_GPU=$withGPU -DGPU_LANG=$gpuLang -DGPU_VENDOR=$gpuVendor -DWITH_GPU_AWARE_MPI=$withGPUAwareMPI -DCMAKE_HIP_FLAGS="$device_flags" -DCMAKE_CUDA_FLAGS="$device_flags" -DCMAKE_CUDA_ARCHITECTURES="$device_architectures" -DCMAKE_HIP_ARCHITECTURES=$device_architectures -DWITH_TESTING=$testing -DMINIMAL_COMPILE=$minimal_compile -DHIGHERQUAD_PSP=$withHigherQuadPSP -DUSE_64BIT_INT=$useInt64 -DWITH_COMPLEX=OFF $dftfeDir/src
  make -j$nprocs

  cd $dftfeDir/install
  echo "Compiling DFTFE complex executable"
  mkdir -p complex && cd complex
  cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$mpi_cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_BUILD_TYPE=Release -DDEAL_II_DIR=$dealiiComplexDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=$withDCCL -DWITH_TORCH=OFF -DCMAKE_PREFIX_PATH="$elpaDir;$dcclDir;$numdiffDir;$dftdDir" -DWITH_GPU=$withGPU -DGPU_LANG=$gpuLang -DGPU_VENDOR=$gpuVendor -DWITH_GPU_AWARE_MPI=$withGPUAwareMPI -DCMAKE_HIP_FLAGS="$device_flags" -DCMAKE_CUDA_FLAGS="$device_flags" -DCMAKE_CUDA_ARCHITECTURES="$device_architectures" -DCMAKE_HIP_ARCHITECTURES=$device_architectures -DWITH_TESTING=$testing -DMINIMAL_COMPILE=$minimal_compile -DHIGHERQUAD_PSP=$withHigherQuadPSP -DUSE_64BIT_INT=$useInt64 -DWITH_COMPLEX=ON $dftfeDir/src
  make -j$nprocs
fi

if [[ $cleanSrc ]]; then
  cd $dependencyDir/src
  rm -rf *
fi
