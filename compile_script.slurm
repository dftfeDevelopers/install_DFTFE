#!/bin/bash
# Build DFT-FE and its dependencies on PARAM Rudra.
#
# Compiling CUDA code does not need a live GPU, so this runs on a CPU partition.
# DFTFE_SYSROOT_INC must be populated from the LOGIN node first
# -- see README.md, "Prerequisites".
#SBATCH -p terai
#SBATCH -N 1
#SBATCH -n 48
#SBATCH --mem=175G
#SBATCH -t 1-00:00:00
#SBATCH -J dftfe-build
#SBATCH -o dftfe-build-%j.out
#SBATCH -e dftfe-build-%j.out

MYPROJECTDIR=${MYPROJECTDIR:-$HOME/dftfe}

module load spack
. /home/apps/spack/share/spack/setup-env.sh
spack load gcc@13.4.0
spack load cuda@12.9.1
export CUDA_HOME=$(spack location -i cuda@12.9.1)

# OpenMPI + UCX built from the HPC-X sources with the same GCC (see README.md)
HPCX=${HPCX:-$MYPROJECTDIR/hpcx-gcc13}
export PATH=$HPCX/ompi/bin:$PATH
export LD_LIBRARY_PATH=$HPCX/ompi/lib:$HPCX/ucx/lib:$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# extra include directory consumed by install_dftfe.sh via -idirafter
export DFTFE_SYSROOT_INC=${DFTFE_SYSROOT_INC:-$MYPROJECTDIR/sysroot/usr/include}
if [ ! -e "$DFTFE_SYSROOT_INC/stdio.h" ]; then
  echo "ERROR: $DFTFE_SYSROOT_INC/stdio.h not found."
  echo "Populate it from the LOGIN node first (see README.md)."
  exit 1
fi

cd "$MYPROJECTDIR/install_DFTFE" || exit 1
bash ./install_dftfe.sh --download --all --nprocs=44
echo "install_dftfe.sh exit=$?"
