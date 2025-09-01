# Install DFT-FE on NSM Machines
This repository provides a **bash-based install script** to build [DFT-FE](https://github.com/dftfeDevelopers/dftfe) and its dependencies on **NSM** machines.
To use this script, clone the repository on the system where you plan to install DFT-FE. For example, to install into `$MYPROJECTDIR/install_DFTFE`:
```bash
cd "$MYPROJECTDIR"
git clone https://github.com/dftfeDevelopers/install_DFTFE.git install_DFTFE
cd install_DFTFE
git checkout nsm_A100
chmod +x install_dftfe.sh
```

# Prerequisites
The following modules need to be loaded:
```bash
GCC
Open MPI
NVCC
CUDA MATH LIBRARY
```

## Installation
To install DFT-FE, navigate to `$MYPROJECTDIR/install_DFTFE` and either run (use `--nprocs=2` (default)):
```bash
./install_dftfe.sh [OPTIONS]
```
or submit a job script. The following options are available to download, compile, and install DFT-FE and its dependencies:
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
