# Install DFT-FE on Polaris
This repository provides a **bash-based install script** to build [DFT-FE](https://github.com/dftfeDevelopers/dftfe) and its dependencies on the **ALCF Polaris** supercomputer.
To use this script, clone the repository on the system where you plan to install DFT-FE. For example, to install into `$MYPROJECTDIR/install_DFTFE`:
```bash
cd "$MYPROJECTDIR"
git clone https://github.com/dftfeDevelopers/install_DFTFE.git install_DFTFE
cd install_DFTFE
git checkout polarisScript
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
--branch=$BRANCH    | Optional: Specify the DFT-FE branch to download or compile. If provided, the
                    | same branch must be used consistently with --download, --all, or --dftfe.
                    | Default: `publicGithubDevelop`.
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
--dftfe             | Compile and install DFT-FE branch specified by `--branch` (default `publicGithubDevelop`))
```

## Running DFT-FE
DFT-FE is built in real and complex versions, depending on whether you want to enable k-points (supported only in the complex version). An example PBS job submission script for running GPU-enabled DFT-FE on a single node is shown below:
```bash
#!/bin/bash -l
#PBS -l select=8:system=polaris
#PBS -l place=scatter
#PBS -l walltime=00:10:00
#PBS -l filesystems=home:eagle
#PBS -q debug-scaling
#PBS -A DFTCalculations
module load craype-accel-nvidia80
module use /soft/modulefiles
module load spack-pe-base cmake
module load PrgEnv-gnu/8.6.0
module load cudatoolkit-standalone/12.9.1

export PYTHON=python3
export NCCL_NET_GDR_LEVEL=PHB
export NCCL_CROSS_NIC=1
export NCCL_COLLNET_ENABLE=1
export NCCL_NET="AWS Libfabric"
export LD_LIBRARY_PATH=/soft/libraries/aws-ofi-nccl/v1.9.1-aws/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/soft/libraries/hwloc/lib/:$LD_LIBRARY_PATH
export FI_CXI_DISABLE_HOST_REGISTER=1
export FI_MR_CACHE_MONITOR=userfaultfd
export FI_CXI_DEFAULT_CQ_SIZE=131072
export LIBRARY_PATH=$LD_LIBRARY_PATH:$LIBRARY_PATH
# Enable GPU-MPI (if supported by application)
export MPICH_GPU_SUPPORT_ENABLED=1
export CRAY_ACCEL_TARGET=nvidia80
export CRAY_TCMALLOC_MEMFS_FORCE=1
export CRAYPE_LINK_TYPE=dynamic
export CRAY_ACCEL_VENDOR=nvidia
export PE_PRODUCT_LIST=$PE_PRODUCT_LIST:CRAY_ACCEL
# Change to working directory
cd ${PBS_O_WORKDIR}
ls ${PBS_O_WORKDIR}
# MPI and OpenMP settings
NNODES=`wc -l < $PBS_NODEFILE`
NRANKS_PER_NODE=$(nvidia-smi -L | wc -l)
NDEPTH=8
NTHREADS=8
export DFTFE_NUM_THREADS=8
NTOTRANKS=$(( NNODES * NRANKS_PER_NODE ))
echo "NUM_OF_NODES= ${NNODES} TOTAL_NUM_RANKS= ${NTOTRANKS} RANKS_PER_NODE= ${NRANKS_PER_NODE} THREADS_PER_RANK= ${NTHREADS}"
exe=/home/phanim/softwares/DFTFEinstallation/dftfe_PawReimplementation/install/real/dftfe
# For applications that internally handle binding MPI/OpenMP processes to GPUs
#mpiexec -n ${NTOTRANKS} --ppn ${NRANKS_PER_NODE} --depth=${NDEPTH} --cpu-bind depth --env OMP_NUM_THREADS=${NTHREADS} -env OMP_PLACES=threads ./hello_affinity
# For applications that need mpiexec to bind MPI ranks to GPUs
mpiexec -n ${NTOTRANKS} --ppn ${NRANKS_PER_NODE} --depth=${NDEPTH} --cpu-bind depth --env OMP_NUM_THREADS=${NTHREADS} -env OMP_PLACES=threads ./set_affinity_gpu_polaris.sh $exe parameterFileGPU_Poly6Mesh2D0.prm > Trial.op
```
