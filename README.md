# Install DFT-FE on PARAM Rudra
This repository provides a **bash-based install script** to build [DFT-FE](https://github.com/dftfeDevelopers/dftfe) and its dependencies on the **PARAM Rudra** supercomputer (CDAC, 2x NVIDIA A100 80GB per node).
To use this script, clone the repository on the system where you plan to install DFT-FE. For example, to install into `$MYPROJECTDIR/install_DFTFE`:
```bash
cd "$MYPROJECTDIR"
git clone https://github.com/dftfeDevelopers/install_DFTFE.git install_DFTFE
cd install_DFTFE
git checkout paramRudraInstall
chmod +x install_dftfe.sh
```

# Prerequisites
There are no standalone `gcc`/`openmpi`/`cuda` modules on PARAM Rudra; the compilers and CUDA come from Spack:
```bash
module load spack
. /home/apps/spack/share/spack/setup-env.sh
spack load gcc@13.4.0
spack load cuda@12.9.1
export CUDA_HOME=$(spack location -i cuda@12.9.1)

export PATH=$HPCX/ompi/bin:$PATH        # OpenMPI + UCX built from the HPC-X sources
```
The Spack UCX is built without InfiniBand support, so build OpenMPI and UCX from the HPC-X sources (HPC-X v2.25.1 provides OpenMPI 4.1.9 and UCX 1.20) using the same GCC 13.4.0, and point `$HPCX` at that installation. BLAS/LAPACK/ScaLAPACK are built from source by the install script (BLIS, libFLAME, netlib ScaLAPACK).

The install script adds one extra include directory via `-idirafter`. Populate it from the login node before building:
```bash
mkdir -p $HOME/dftfe/sysroot/usr
cp -a /usr/include $HOME/dftfe/sysroot/usr/
cp -a /usr/lib64   $HOME/dftfe/sysroot/usr/
ln -s usr/lib64    $HOME/dftfe/sysroot/lib64
chmod -R u+w       $HOME/dftfe/sysroot
export DFTFE_SYSROOT_INC=$HOME/dftfe/sysroot/usr/include   # default if unset
```
`-idirafter` is used rather than `-I`, `-isystem` or `CPATH` because libstdc++'s C-compatibility headers (`<cstdlib>`, `<cmath>`, ...) reach the underlying C header through `#include_next`, which only continues searching directories placed after gcc's own bundled headers.

## Installation
Installation can be done from the login node (use `--nprocs=2` (default)). Preferably, it should be performed on a compute node using the provided job script `compile_script.slurm`.
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
--nprocs=N          | Optional: Set the number of parallel tasks for compilation. Default: 44.
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
DFT-FE is built in real and complex versions, depending on whether you want to enable k-points (supported only in the complex version). Use `mpirun`, or `srun --mpi=pmix`; a plain `srun` launches singleton MPI processes. An example Slurm job submission script for running GPU-enabled DFT-FE on 5 nodes (10 GPUs) is shown below:
```bash
#!/bin/bash
#SBATCH -p gpu-small
#SBATCH -N 5
#SBATCH --ntasks-per-node=48
#SBATCH --gres=gpu:2
#SBATCH --mem=175G
#SBATCH -t 04:00:00
#SBATCH -J dftfe
#SBATCH -o output.log
#SBATCH -e error.log

MYPROJECTDIR=$HOME/dftfe

module load spack
. /home/apps/spack/share/spack/setup-env.sh
spack load gcc@13.4.0
spack load cuda@12.9.1
CUDA_HOME=$(spack location -i cuda@12.9.1)
export PATH=$HPCX/ompi/bin:$PATH

D=$MYPROJECTDIR/install_DFTFE/dependencies
# both lib and lib64 are needed: spglib, libxc and Kokkos install into lib64
export LD_LIBRARY_PATH=$D/lib:$D/lib64:$HPCX/ompi/lib:$HPCX/ucx/lib:$CUDA_HOME/lib64:$LD_LIBRARY_PATH
export OMP_NUM_THREADS=1 DFTFE_NUM_THREADS=1 DEAL_II_NUM_THREADS=1
export ELPA_DEFAULT_omp_threads=1

# MPI settings: one rank per GPU
NRANKS_PER_NODE=$(nvidia-smi -L | wc -l)
NTOTRANKS=$(( SLURM_JOB_NUM_NODES * NRANKS_PER_NODE ))
echo "NUM_OF_NODES= ${SLURM_JOB_NUM_NODES} TOTAL_NUM_RANKS= ${NTOTRANKS} RANKS_PER_NODE= ${NRANKS_PER_NODE}"

exe=$MYPROJECTDIR/install_DFTFE/dftfe_publicGithubDevelop/install/real/dftfe

mpirun -n ${NTOTRANKS} --map-by ppr:${NRANKS_PER_NODE}:node $exe parameterFileGPU.prm > output
```
