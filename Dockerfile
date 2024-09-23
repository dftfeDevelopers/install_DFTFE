# Use an Ubuntu base image
FROM ubuntu:20.04
# Set environment variables for non-interactive tzdata configuration
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York
# Set environment variables to allow running mpirun as root
ENV OMPI_ALLOW_RUN_AS_ROOT=1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

# Install necessary packages and configure tzdata
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y \
        software-properties-common \
        python3.9 \
        python3.9-dev \
        python3.9-venv \
        python3-pip \
        openmpi-bin \
        libopenmpi-dev \
        gcc-10 \
        g++-10 \
        gfortran-10 \
        libxml2-dev \
        make \
        vim \
        tzdata \
        cmake \
        git \
        wget \
        perl \
        doxygen \
        graphviz \
        libssl-dev \
        libboost-all-dev \
        numdiff \
        pkg-config \
        && ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
        && dpkg-reconfigure --frontend noninteractive tzdata \
        && rm -rf /var/lib/apt/lists/*

# Set gcc, g++, and gfortran version 10 as the default compilers
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 10 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 10 && \
    update-alternatives --install /usr/bin/gfortran gfortran /usr/bin/gfortran-10 10

# Set environment variables for OpenMPI to use gcc-10, g++-10, and gfortran-10
ENV OMPI_CC=gcc-10 \
    OMPI_CXX=g++-10 \
    OMPI_FC=gfortran-10

# Verify installation
RUN mpicc --showme:compiler && \
    mpicxx --showme:compiler && \
    mpif90 --showme:compiler

# Set the CMake version and prefix location
ENV CMAKE_VERSION=3.30.3
ENV CMAKE_PREFIX=/usr/local/cmake

# Download, build, and install CMake from source
RUN wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz \
    && tar -xzvf cmake-${CMAKE_VERSION}.tar.gz \
    && rm cmake-${CMAKE_VERSION}.tar.gz \
    && cd cmake-${CMAKE_VERSION} \
    && ./bootstrap --prefix=${CMAKE_PREFIX} \
    && make -j16 \
    && make install \
    && cd .. \
    && rm -rf cmake-${CMAKE_VERSION}

# Add CMake to PATH and set it as the default
ENV PATH=${CMAKE_PREFIX}/bin:$PATH

# Verify the CMake version
RUN cmake --version

# Install numpy using pip
RUN pip3 install numpy
RUN apt-get update && apt-get install -y curl
RUN curl -sL https://deb.nodesource.com/setup_20.x | bash -
RUN apt-get install -y nodejs
# Verify installation
RUN node --version
RUN npm --version
WORKDIR /usr/src/app/
COPY . .

## Start DFT-FE installation in the correct directory
# Set environment variables required by the DFT-FE installer script
ENV WD=/usr/src/app/DFTFE/build
ENV INST=/usr/src/app/DFTFE/install

# Create working and installation directories
RUN mkdir -p $WD $INST
WORKDIR /usr/src/app/DFTFE/build
# Copy the DFT-FE installation script
RUN wget https://raw.githubusercontent.com/dftfeDevelopers/install_DFTFE/generalUbuntuCPU/dftfeInstall.sh -O dftfeInstall.sh
RUN chmod +x dftfeInstall.sh
#RUN ls -lrt
# Install dependencies for DFT-FE
RUN bash -c "source ./dftfeInstall.sh && install_openblas"
RUN bash -c "source ./dftfeInstall.sh && install_netlib_lapack"
RUN bash -c "source ./dftfeInstall.sh && install_alglib"
RUN bash -c "source ./dftfeInstall.sh && install_libxc"
RUN bash -c "source ./dftfeInstall.sh && install_spglib"
RUN bash -c "source ./dftfeInstall.sh && install_p4est"
RUN bash -c "source ./dftfeInstall.sh && install_scalapack"
RUN bash -c "source ./dftfeInstall.sh && install_elpa"
RUN bash -c "source ./dftfeInstall.sh && install_kokkos"
RUN bash -c "source ./dftfeInstall.sh && install_dealii"


# Compile DFT-FE
RUN bash -c "source ./dftfeInstall.sh && compile_dftfe"

# Expose environment variables for the executables
ENV DFTFE_REAL=$WD/src/dftfe_publicGithubDevelop/build/release/real/dftfe
ENV DFTFE_COMPLEX=$WD/src/dftfe_publicGithubDevelop/build/release/complex/dftfe

# # Create scratch directory with subdirectories
RUN mkdir -p /usr/src/app/scratch/inputs /usr/src/app/scratch/outputs
WORKDIR /usr/src/app/
# # Install app dependencies
RUN npm i
ENTRYPOINT [ "npm", "start" ]
