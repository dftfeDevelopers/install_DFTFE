#!/bin/bash
# Installation script for DFT-FE and its dependencies

# Install alglib, libxc, spglib and p4est using the typical route (cf. manual)
function install_alglib {
  cd $WD/src
  if [ ! -d alglib-cpp ]; then 
    wget https://www.alglib.net/translator/re/alglib-3.20.0.cpp.gpl.tgz
    tar xzf alglib-3.20.0.cpp.gpl.tgz
    rm -f alglib-3.20.0.cpp.gpl.tgz
  fi
  cd alglib-cpp/src
  g++ -o libAlglib.so -shared -fPIC -O2 *.cpp

  mkdir -p $INST/lib/alglib
  mv libAlglib.so $INST/lib/alglib/
  cp *.h $INST/lib/alglib/

  cd $WD
}

function install_libxc {
  cd $WD/src
  if [ ! -d libxc-6.2.2 ]; then 
    wget https://gitlab.com/libxc/libxc/-/archive/6.2.2/libxc-6.2.2.tar.gz
    tar xzf libxc-6.2.2.tar.gz
    rm libxc-6.2.2.tar.gz
  fi
  cd libxc-6.2.2
  rm -fr build
  mkdir build && cd build
  cmake -DCMAKE_C_COMPILER=gcc -DCMAKE_C_FLAGS="-O2 -fPIC" -DCMAKE_CXX_COMPILER=g++ -DCMAKE_CXX_FLAGS="-O2 -fPIC" -DCMAKE_INSTALL_PREFIX=$INST -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF ..
  make -j16
  make install
  cd $WD
}


function install_dftd4 {
  cd $WD/src
  if [ ! -d dftd4-3.6.0 ]; then
    wget https://github.com/dftd4/dftd4/archive/refs/tags/v3.6.0.tar.gz
    tar xzf v3.6.0.tar.gz
    rm v3.6.0.tar.gz
  fi
  cd dftd4-3.6.0
  rm -fr build
  mkdir build && cd build
  cmake -DCMAKE_Fortran_COMPILER=gfortran -DCMAKE_C_COMPILER=gcc -DBLAS_LIBRARIES=user/lib/libopenblas.so -DLAPACK_LIBRARIES=$OLCF_OPENBLAS_ROOT/lib/libopenblas.so -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=$INST -DWITH_OpenMP=OFF ..
  make -j16
  make install
  cd $WD
}

function install_spglib {
  cd $WD/src
  if [ ! -d spglib ]; then
    git clone https://github.com/atztogo/spglib.git
    rc -c cd spglib && git checkout 02159eef6e7349535049a43fe2272bb634c77945
  fi
  cd spglib
  rm -fr build
  mkdir -p build && cd build
  cmake -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc -DCMAKE_INSTALL_PREFIX=$INST ..
  make -j16
  make install
  cd $WD
}

function install_p4est {
  cd $WD/src
  rm -rf p4est
  mkdir p4est
  cd p4est
  wget https://p4est.github.io/release/p4est-2.8.6.tar.gz
  wget https://raw.githubusercontent.com/dftfeDevelopers/dftfe/manual/p4est-setup-ubuntu.sh
  chmod u+x p4est-setup-ubuntu.sh
  ./p4est-setup-ubuntu.sh p4est-2.8.6.tar.gz $INST
  cd $WD
 }


# Install netlib-scalapack 2.2.0 version linking to openblas
# note that the openblas (sourced via module) provides lapack
function install_scalapack {
  cd $WD/src
  if [ ! -d scalapack-2.2.0 ]; then
    wget https://github.com/Reference-ScaLAPACK/scalapack/archive/refs/tags/v2.2.0.tar.gz
    tar xzf v2.2.0.tar.gz
    rm -f v2.2.0.tar.gz
  fi
  cd scalapack-2.2.0
  
  mkdir build && cd build
  cmake -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_C_COMPILER=mpicc -DCMAKE_Fortran_COMPILER=mpif90 -DCMAKE_C_FLAGS="-fPIC -march=native" -DCMAKE_Fortran_FLAGS="-fPIC -march=native -fallow-argument-mismatch" -DUSE_OPTIMIZED_LAPACK_BLAS=ON -DCMAKE_INSTALL_PREFIX=$INST ..
  make -j16
  make install
  cd $WD
}


# Install ELPA latest version (elpa-2024.03.001)
function install_elpa {
    cd $WD/src
    if [ ! -d elpa ]; then
        ver=2024.03.001
        wget https://elpa.mpcdf.mpg.de/software/tarball-archive/Releases/$ver/elpa-$ver.tar.gz
        tar xzf elpa-$ver.tar.gz
        mv elpa-$ver elpa
        rm -f elpa-$ver.tar.gz
        cd ..
    fi
    cd elpa

    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$INST/lib
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$INST/lib64

    rm -fr build
    mkdir build && cd build
    ../configure CXX=mpic++ CC=mpicc FC=mpif90 CFLAGS="-march=native -fPIC -O2" FCFLAGS="-march=native -O2 -fPIC" CXXFLAGS="-std=c++17 -march=native -fPIC -O2" LIBS="-L$INST/lib -lscalapack -L$OLCF_OPENBLAS_ROOT/lib -lopenblas -L$INST/lib64" -prefix=$INST --disable-avx512 --enable-c-tests=no --enable-option-checking=fatal --enable-shared --enable-cpp-tests=no
    make -j16
    make install
    cd $WD
}


function install_kokkos {
  cd $WD/src
  if [ ! -d kokkos-4.3.00 ]; then 
    wget https://github.com/kokkos/kokkos/archive/refs/tags/4.3.00.tar.gz
    tar xzvf 4.3.00.tar.gz
    rm 4.3.00.tar.gz
  fi
  cd kokkos-4.3.00
  rm -fr build
  mkdir build && cd build
  cmake -DCMAKE_C_COMPILER=mpicc -DCMAKE_C_FLAGS="-O2 -fPIC" -DCMAKE_CXX_COMPILER=mpic++ -DCMAKE_CXX_FLAGS="-O2 -fPIC" -DCMAKE_INSTALL_PREFIX=$INST ..
  make -j16
  make install
  cd $WD
}


# Install latest release dealii from https://github.com/dealii/dealii

function install_dealii {
  cd $WD/src
  ver=9.5.2
  if [ ! -d dealii-$ver ]; then
      wget https://github.com/dealii/dealii/releases/download/v$ver/dealii-$ver.tar.gz
      tar xzf dealii-$ver.tar.gz 
  fi
  cd dealii-$ver
  rm -fr build
  mkdir build && cd build
  cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_FLAGS="-march=native -std=c++17" -DCMAKE_C_FLAGS=-march=native -DDEAL_II_ALLOW_PLATFORM_INTROSPECTION=OFF -DDEAL_II_FORCE_BUNDLED_BOOST=OFF -DDEAL_II_WITH_TASKFLOW=OFF -DKOKKOS_DIR=$INST -DCMAKE_BUILD_TYPE=Release -DDEAL_II_CXX_FLAGS_RELEASE=-O2 -DCMAKE_C_COMPILER=mpicc -DCMAKE_CXX_COMPILER=mpic++ -DCMAKE_Fortran_COMPILER=mpif90 -DDEAL_II_WITH_TBB=OFF -DDEAL_II_COMPONENT_EXAMPLES=OFF -DDEAL_II_WITH_MPI=ON -DDEAL_II_WITH_64BIT_INDICES=ON -DP4EST_DIR=$INST -DDEAL_II_WITH_LAPACK=ON -DLAPACK_DIR="usr/;$INST" -DLAPACK_FOUND=true -DLAPACK_LIBRARIES="usr/lib/libopenblas.so" -DCMAKE_INSTALL_PREFIX=$INST ..
  make -j16 
  make install
  mv $INST/*.log $INST/share/deal.II/
  mv $INST/*.md $INST/share/deal.II/
  cd $WD
}


function compile_dftfe {
  cd $WD/src
  if [ ! -z $1 ]; then
    branch=$1
  else
    branch=publicGithubDevelop
  fi
  if [ ! -d dftfe_$branch ]; then
    git clone -b $branch https://github.com/dftfeDevelopers/dftfe dftfe_$branch
    cd dftfe_$branch
  else
    cd dftfe_$branch
    git checkout $branch
    git pull
  fi
  rm -fr build
  SRC=$PWD
  mkdir build && cd build

  dealiiDir=$INST
  alglibDir=$INST/lib/alglib
  libxcDir=$INST
  spglibDir=$INST
  xmlIncludeDir=/usr/include/libxml2
  xmlLibDir=/usr/lib64

  ELPA_PATH=$INST

  #Compiler options and flags
  cxx_compiler=mpic++
  cxx_flags="-march=native -fPIC"
  cxx_flagsRelease=-O2 #sets DCMAKE_CXX_FLAGS_RELEASE

  # HIGHERQUAD_PSP option compiles with default or higher order
  # quadrature for storing pseudopotential data
  # ON is recommended for MD simulations with hard pseudopotentials

  # build type: "Release" or "Debug"
  build_type=Release
  out=`echo "$build_type" | tr '[:upper:]' '[:lower:]'`

  function cmake_real {
    mkdir -p real && cd real
    cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_CXX_FLAGS_RELEASE="$cxx_flagsRelease" -DCMAKE_BUILD_TYPE=$build_type -DDEAL_II_DIR=$dealiiDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=OFF -DWITH_TORCH=OFF -DCMAKE_PREFIX_PATH="$ELPA_PATH" -DWITH_GPU=OFF -DWITH_TESTING=OFF -DMINIMAL_COMPILE=OFF -DHIGHERQUAD_PSP=ON -DWITH_COMPLEX=OFF $1
    make -j16
    cd ..
  }

  function cmake_cplx {
    mkdir -p complex && cd complex
    cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_CXX_FLAGS_RELEASE="$cxx_flagsRelease" -DCMAKE_BUILD_TYPE=$build_type -DDEAL_II_DIR=$dealiiDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=OFF -DWITH_TORCH=OFF -DCMAKE_PREFIX_PATH="$ELPA_PATH" -DWITH_GPU=OFF -DWITH_TESTING=OFF -DMINIMAL_COMPILE=OFF -DHIGHERQUAD_PSP=ON -DWITH_COMPLEX=ON $1
    make -j16
    cd ..
  }

  mkdir -p $out
  cd $out

  echo Building Real executable in $build_type mode...
  cmake_real $SRC

  echo Building Complex executable in $build_type mode...
  cmake_cplx $SRC

  echo Build complete.
  cd $WD
}
