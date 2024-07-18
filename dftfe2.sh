#!/bin/bash
# Installation script for DFT-FE and its dependencies

. ./env2/env.sh

# Install alglib, libxc, spglib and p4est using the typical route (cf. manual)
function install_alglib {
  cd $WD/src
  if [ ! -d alglib-cpp ]; then 
    wget https://www.alglib.net/translator/re/alglib-3.20.0.cpp.gpl.tgz
    tar xzf alglib-3.20.0.cpp.gpl.tgz
    rm -f alglib-3.20.0.cpp.gpl.tgz
  fi
  cd alglib-cpp/src
  CC -o libAlglib.so -shared -fPIC -O2 *.cpp

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
  cmake -DCMAKE_C_COMPILER=cc -DCMAKE_C_FLAGS="-O2 -fPIC" -DCMAKE_CXX_COMPILER=CC -DCMAKE_CXX_FLAGS="-O2 -fPIC" -DCMAKE_INSTALL_PREFIX=$INST -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF ..
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
  cmake -DCMAKE_Fortran_COMPILER=ftn -DCMAKE_C_COMPILER=cc -DBLAS_LIBRARIES=$OLCF_OPENBLAS_ROOT/lib/libopenblas.so -DLAPACK_LIBRARIES=$OLCF_OPENBLAS_ROOT/lib/libopenblas.so -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=$INST -DWITH_OpenMP=OFF ..
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
  cmake -DCMAKE_CXX_COMPILER=CC -DCMAKE_C_COMPILER=cc -DCMAKE_INSTALL_PREFIX=$INST ..
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
  wget https://raw.githubusercontent.com/dftfeDevelopers/dftfe/manual/p4est-setup-craycompiler.sh
  chmod u+x p4est-setup-craycompiler.sh
  ./p4est-setup-craycompiler.sh p4est-2.8.6.tar.gz $INST
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
  cmake -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_C_COMPILER=cc -DCMAKE_Fortran_COMPILER=ftn -DCMAKE_C_FLAGS="-fPIC -march=znver3" -DCMAKE_Fortran_FLAGS="-fPIC -march=znver3 -fallow-argument-mismatch" -DUSE_OPTIMIZED_LAPACK_BLAS=ON -DCMAKE_INSTALL_PREFIX=$INST ..
  make -j16
  make install
  cd $WD
}

# Install RCCL (https://github.com/ROCmSoftwarePlatform/rccl)
#    cmake -DCMAKE_CXX_COMPILER=${ROCM_PATH}/bin/hipcc -DCMAKE_CXX_FLAGS="-I${MPICH_DIR}/include -I${ROCM_PATH}/include" -DCMAKE_SHARED_LINKER_FLAGS="-L${ROCM_PATH}/lib -lamdhip64 -L${MPICH_DIR}/lib -lmpi -L${CRAY_MPICH_ROOTDIR}/gtl/lib -lmpi_gtl_hsa" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$ROCM_PATH;${MPICH_DIR}" ../

# Install RCCL OFI plugin
function install_ofi_rccl {
  cd $WD/src
  if [ ! -d aws-ofi-rccl ]; then 
    git clone https://github.com/ROCmSoftwarePlatform/aws-ofi-rccl
    cd aws-ofi-rccl
    module load libtool
    bash ./autogen.sh
  fi
  cd aws-ofi-rccl
  rm -fr build
  mkdir build && cd build

  CC=cc ../configure --with-libfabric=/opt/cray/libfabric/1.15.2.0 --with-hip=$CRAY_ROCM_PREFIX --with-rccl=$CRAY_ROCM_PREFIX --with-mpi=$MPICH_DIR --prefix=$INST --build=amd64-linux-gnu --target=amd64-linux-gnu --host=amd64-linux-gnu
  make -j8
  make install
  cd $WD
}

# Install ELPA latest version (elpa-2024.03.001) with AMD GPU support
function install_elpa {
    cd $WD/src
    if [ ! -d elpa ]; then
        ver=2024.03.001
        wget https://elpa.mpcdf.mpg.de/software/tarball-archive/Releases/$ver/elpa-$ver.tar.gz
        tar xzf elpa-$ver.tar.gz
        mv elpa-$ver elpa
        rm -f elpa-$ver.tar.gz
        cd elpa && patch -p1 <$WD/src/elpa-$ver.patch
        cd ..
    fi
    cd elpa

    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$INST/lib
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$INST/lib64
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ROCM_PATH/lib

    rm -fr build
    mkdir build && cd build
    ../configure CXX=hipcc CC=hipcc FC=ftn CFLAGS="-march=znver3 -fPIC -O2 -I$ROCM_PATH/include --amdgpu-target=gfx90a -I$MPICH_DIR/include" FCFLAGS="-march=znver3 -O2 -fPIC" CXXFLAGS="-std=c++17 -march=znver3 -fPIC -O2 -I$ROCM_PATH/include --amdgpu-target=gfx90a -I$MPICH_DIR/include" LIBS="-L$ROCM_PATH/lib -lamdhip64 -lrocblas -L$MPICH_DIR/lib -lmpi $CRAY_XPMEM_POST_LINK_OPTS -lxpmem $PE_MPICH_GTL_DIR_amd_gfx90a $PE_MPICH_GTL_LIBS_amd_gfx90a -L$INST/lib -lscalapack -L$OLCF_OPENBLAS_ROOT/lib -lopenblas -L$INST/lib64" --enable-amd-gpu --prefix=$INST --disable-sse -disable-sse-assembly --disable-avx --disable-avx2 --disable-avx512 --enable-c-tests=no --enable-option-checking=fatal --enable-shared --enable-cpp-tests=no --enable-hipcub
#              --enable-gpu-streams=amd
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
  cmake -DCMAKE_C_COMPILER=cc -DCMAKE_C_FLAGS="-O2 -fPIC" -DCMAKE_CXX_COMPILER=CC -DCMAKE_CXX_FLAGS="-O2 -fPIC" -DCMAKE_INSTALL_PREFIX=$INST ..
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
  cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_FLAGS="-march=native -std=c++17" -DCMAKE_C_FLAGS=-march=native -DDEAL_II_ALLOW_PLATFORM_INTROSPECTION=OFF         -DDEAL_II_FORCE_BUNDLED_BOOST=ON -DDEAL_II_WITH_TASKFLOW=OFF -DKOKKOS_DIR=$INST -DCMAKE_BUILD_TYPE=Release -DDEAL_II_CXX_FLAGS_RELEASE=-O2 -DCMAKE_C_COMPILER=cc -DCMAKE_CXX_COMPILER=CC -DCMAKE_Fortran_COMPILER=ftn -DDEAL_II_WITH_TBB=OFF -DDEAL_II_COMPONENT_EXAMPLES=OFF -DDEAL_II_WITH_MPI=ON -DDEAL_II_WITH_64BIT_INDICES=ON -DP4EST_DIR=$INST -DDEAL_II_WITH_LAPACK=ON -DLAPACK_DIR="$OLCF_OPENBLAS_ROOT;$INST" -DLAPACK_FOUND=true -DLAPACK_LIBRARIES="$OLCF_OPENBLAS_ROOT/lib/libopenblas.so" -DCMAKE_INSTALL_PREFIX=$INST ..
  make -j16 
  make install
  mv $INST/*.log $INST/share/deal.II/
  mv $INST/*.md $INST/share/deal.II/
  cd $WD
}

function install_torch {
  PYTORCH_VERSION=1.13.1
  PYTORCH_URL=https://github.com/pytorch/pytorch

  cd $WD/src
  enter_venv
  pip install pyyaml pandas matplotlib scikit-learn pybind11 \
      typing_extensions six sympy filelock jinja2 networkx
  if [ ! -d pytorch]; then 
      git clone --recursive $PYTORCH_URL
      cd pytorch && git checkout v$PYTORCH_VERSION
  fi
  cd pytorch
  CMAKE_PREFIX_PATH=$INST
  CMAKE_CXX_FLAGS=-march=znver3
  CXX=`{which g++} # note: CC adds mpi linking info.
  CC=`{which gcc}
  BLAS=OpenBLAS
  OpenBLAS_HOME=$OLCF_OPENBLAS_ROOT
  USE_CUDA=0
  USE_ROCM=0
  USE_CUDNN=0
  USE_NCCL=0
  USE_RCCL=0
  USE_MKLDNN=0
  USE_DISTRIBUTED=0
  USE_OPENMP=0
  PYTORCH_BUILD_VERSION=$PYTORCH_VERSION # to prevent dependency issues
  PYTORCH_BUILD_NUMBER=1
  CMAKE_BUILD_TYPE=Release

  python setup.py build -j16 --cmake-only
  cd build
  #cmake -DBUILD_CUSTOM_PROTOBUF=0 ..
  cmake --build . -j16 --target install
  cd ..
  python3 setup.py install

  cd $WD
}

function compile_dftfe_debug {
  branch=multiVecOps
  cd $WD/src
  if [ ! test -d dftfeDebug ]; then
    git clone -b $branch https://dsambit@bitbucket.org/dftfedevelopers/dftfe.git dftfeDebug
  else
    cd dftfeDebug
    git fetch
    git checkout $branch
    git pull
  fi
  cd dftfeDebug
  rm -fr build
  SRC=$PWD
  mkdir build && cd build
  #cd build

  dealiiDir=$INST
  alglibDir=$INST/lib/alglib
  libxcDir=$INST
  spglibDir=$INST
  xmlIncludeDir=/usr/include/libxml2
  xmlLibDir=/usr/lib64

  ELPA_PATH=$INST
  DCCL_PATH=$ROCM_PATH
  TORCH_PATH=$INST/venv/lib/python3.9/site-packages

  #Compiler options and flags
  cxx_compiler=CC
  cxx_flags="-march=znver3 -fPIC -I$MPICH_DIR/include -I$ROCM_PATH/include"
  cxx_flagsRelease=-O2 #sets DCMAKE_CXX_FLAGS_RELEASE
  device_flags="-march=znver3 -O2 -munsafe-fp-atomics -I$MPICH_DIR/include -I$ROCM_PATH/include"
  device_architectures=gfx90a

  # HIGHERQUAD_PSP option compiles with default or higher order
  # quadrature for storing pseudopotential data
  # ON is recommended for MD simulations with hard pseudopotentials

  # build type: "Release" or "Debug"
  build_type=Release
  out=`echo "$build_type" | tr '[:upper:]' '[:lower:]'`

  # Note: MDI_PATH is not used by project.
  cmake_flags="-DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS=$cxx_flags -DCMAKE_CXX_FLAGS_RELEASE=$cxx_flagsRelease -DDEAL_II_FORCE_BUNDLED_BOOST=OFF -DCMAKE_BUILD_TYPE=$build_type -DDEAL_II_DIR=$dealiiDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=ON -DWITH_TORCH=OFF -DCMAKE_PREFIX_PATH=$ELPA_PATH;$DCCL_PATH;$TORCH_PATH -DWITH_GPU=ON -DGPU_LANG=hip -DGPU_VENDOR=amd -DWITH_GPU_AWARE_MPI=ON -DCMAKE_HIP_FLAGS=$device_flags -DCMAKE_HIP_ARCHITECTURES=$device_architectures -DWITH_TESTING=OFF -DMINIMAL_COMPILE=OFF -DCMAKE_SHARED_LINKER_FLAGS='-L$ROCM_PATH/lib -lamdhip64 -L$MPICH_DIR/lib -lmpi -L$CRAY_XPMEM_POST_LINK_OPTS -lxpmem $PE_MPICH_GTL_DIR_amd_gfx90a $PE_MPICH_GTL_LIBS_amd_gfx90a' -DHIGHERQUAD_PSP=OFF"

  function cmake_real {
    mkdir -p real && cd real
    cmake $cmake_flags \
      -DWITH_COMPLEX=OFF \
      $1
    make -j8
    cd ..
  }

  function cmake_cplx {
    mkdir -p complex && cd complex
    cmake $cmake_flags \
      -DWITH_COMPLEX=ON \
      $1
    make -j8
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



function compile_dftfe {
  cd $WD/src
  if [ ! -z $1 ]; then
    branch=$1
  else
    branch=publicGithubDevelop
  fi
  if [ ! -d dftfe_$branch ]; then
    git clone -b $branch https://knikhil1995@bitbucket.org/dftfedevelopers/dftfe.git dftfe_$branch
  else
    cd dftfe_$branch
    git checkout $branch
    git pull
  fi
  cd dftfe_$branch
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
  DCCL_PATH=$ROCM_PATH/include/rccl
  TORCH_PATH=$INST/venv/lib/python3.9/site-packages

  #Compiler options and flags
  cxx_compiler=CC
  cxx_flags="-march=znver3 -fPIC -I$MPICH_DIR/include -I$ROCM_PATH/include"
  cxx_flagsRelease="-O2" #sets DCMAKE_CXX_FLAGS_RELEASE
  device_flags="-march=znver3 -O2 -munsafe-fp-atomics -I$MPICH_DIR/include -I$ROCM_PATH/include"
  device_architectures=gfx90a

  # HIGHERQUAD_PSP option compiles with default or higher order
  # quadrature for storing pseudopotential data
  # ON is recommended for MD simulations with hard pseudopotentials

  # build type: "Release" or "Debug"
  build_type=Release
  out=`echo "$build_type" | tr '[:upper:]' '[:lower:]'`

  function cmake_real {
    mkdir -p real && cd real
    cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_CXX_FLAGS_RELEASE="$cxx_flagsRelease" -DCMAKE_BUILD_TYPE=$build_type -DDEAL_II_DIR=$dealiiDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=OFF -DWITH_TORCH=OFF -DCMAKE_PREFIX_PATH="$ELPA_PATH;$DCCL_PATH;$TORCH_PATH" -DWITH_GPU=ON -DGPU_LANG=hip -DGPU_VENDOR=amd -DWITH_GPU_AWARE_MPI=OFF -DCMAKE_HIP_FLAGS="$device_flags" -DCMAKE_HIP_ARCHITECTURES=$device_architectures -DWITH_TESTING=OFF -DMINIMAL_COMPILE=OFF -DCMAKE_SHARED_LINKER_FLAGS="-L$ROCM_PATH/lib -lamdhip64 -L$MPICH_DIR/lib -lmpi $CRAY_XPMEM_POST_LINK_OPTS -lxpmem $PE_MPICH_GTL_DIR_amd_gfx90a $PE_MPICH_GTL_LIBS_amd_gfx90a" -DHIGHERQUAD_PSP=ON -DWITH_COMPLEX=OFF $1
    make -j16
    cd ..
  }

  function cmake_cplx {
    mkdir -p complex && cd complex
    cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_COMPILER=$cxx_compiler -DCMAKE_CXX_FLAGS="$cxx_flags" -DCMAKE_CXX_FLAGS_RELEASE="$cxx_flagsRelease" -DCMAKE_BUILD_TYPE=$build_type -DDEAL_II_DIR=$dealiiDir -DALGLIB_DIR=$alglibDir -DLIBXC_DIR=$libxcDir -DSPGLIB_DIR=$spglibDir -DXML_LIB_DIR=$xmlLibDir -DXML_INCLUDE_DIR=$xmlIncludeDir -DWITH_MDI=OFF -DMDI_PATH= -DWITH_DCCL=OFF -DWITH_TORCH=OFF -DCMAKE_PREFIX_PATH="$ELPA_PATH;$DCCL_PATH;$TORCH_PATH" -DWITH_GPU=ON -DGPU_LANG=hip -DGPU_VENDOR=amd -DWITH_GPU_AWARE_MPI=OFF -DCMAKE_HIP_FLAGS="$device_flags" -DCMAKE_HIP_ARCHITECTURES=$device_architectures -DWITH_TESTING=OFF -DMINIMAL_COMPILE=OFF -DCMAKE_SHARED_LINKER_FLAGS="-L$ROCM_PATH/lib -lamdhip64 -L$MPICH_DIR/lib -lmpi $CRAY_XPMEM_POST_LINK_OPTS -lxpmem $PE_MPICH_GTL_DIR_amd_gfx90a $PE_MPICH_GTL_LIBS_amd_gfx90a" -DHIGHERQUAD_PSP=ON -DWITH_COMPLEX=ON $1
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
