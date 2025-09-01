# Install DFT-FE on Polaris
This repository provides a **bash-based install script** to build [DFT-FE](https://github.com/dftfeDevelopers/dftfe) and its dependencies on the **ALCF Polaris** supercomputer.
To use this script, clone the repository on the system where you plan to install DFT-FE. For example, to install into `$MYPROJECTDIR/install_DFTFE`:
```bash
cd "$MYPROJECTDIR"
git clone https://github.com/dftfeDevelopers/install_DFTFE.git install_DFTFE
cd install_DFTFE
git checkout nsm_A100
chmod +x install_dftfe.sh
```

# Prerequisites
The install and job scripts automatically load the required modules and set paths for DFT-FE:
```bash
module use /soft/modulefiles
module load spack-pe-base cmake
module load PrgEnv-gnu/8.6.0
module load cudatoolkit-standalone/12.9.1

export LD_LIBRARY_PATH=/soft/libraries/aws-ofi-nccl/v1.9.1-aws/lib:$LD_LIBRARY_PATH  # AWS OFI NCCL plugin
export LD_LIBRARY_PATH=/soft/libraries/hwloc/lib/:$LD_LIBRARY_PATH                   # hwloc

dcclDir="/soft/libraries/nccl/nccl_2.21.5-1+cuda12.2_x86_64"                         # DCCL
```

## Installation
Installation can be done from the login node (use `--nprocs=2` (default)). Preferably, it should be performed on a compute node using the provided job script `compile_script.sub`.
To install DFT-FE, navigate to `$MYPROJECTDIR/install_DFTFE` and either run:
```bash
./install_dftfe.sh [OPTIONS]
```
or submit the job script. The following options are available to download, compile, and install DFT-FE and its dependencies:
```bash
--download          | Download all required dependencies and DFT-FE
--all               | Download and install all dependencies and DFT-FE
--nprocs=N          | Optional: Set the number of parallel tasks for compilation. Default: 2.
--clean-build-files | Remove all source and build files after compilation
```
After downloading the dependencies and DFT-FE source, you can compile and install them individually if `--all` is not used:
```bash
--blaslapack
--scalapack
--alglib
--spglib
--libxml2
--numdiff
--libxc
--p4est
--kokkos
--boost
--dealii
--elpa
--dftfe             | Compile and install DFT-FE
```
