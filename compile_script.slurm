#!/bin/bash
# Build DFT-FE on PARAM Rudra. Submit from the install_DFTFE directory.
#
# By default this builds DFT-FE (real and complex) for $BRANCH against the
# prebuilt dependencies under $STACK -- see README.md. Compute nodes have no
# internet access, so the DFT-FE source must already be in dftfe_$BRANCH/src.
#
# debug is the only CPU partition that accepts a 1-node job (the others need
# at least 10 nodes). Its 1 h limit is enough for DFT-FE; a full dependency
# build is split over two jobs with STAGES (README.md).
#SBATCH -p debug
#SBATCH -N 1
#SBATCH -n 48
#SBATCH --mem=175G
#SBATCH -t 01:00:00
#SBATCH -J dftfe-build
#SBATCH -o dftfe-build-%j.out
#SBATCH -e dftfe-build-%j.out

PREBUILT=/home/nsmext/phanim.iisc/dftfe
BRANCH=${BRANCH:-publicGithubDevelop}
STAGES=${STAGES:---dftfe}
STACK=${STACK:-$PREBUILT}
HPCX=${HPCX:-$STACK/hpcx-gcc13}
SYSROOT=$STACK/sysroot
export DFTFE_SYSROOT_INC=$SYSROOT/usr/include
export DFTFE_DEPS_DIR=${DFTFE_DEPS_DIR:-$STACK/install_DFTFE/dependencies}
export DFTFE_ELPA_DIR=${DFTFE_ELPA_DIR:-$STACK/install_DFTFE/elpa-2026.02.002}

module load spack
. /home/apps/spack/share/spack/setup-env.sh
# two gcc@13.4.0 records exist and the bare spec does not load
spack load gcc@13.4.0/azyvhui || exit 1
spack load cuda@12.9.1 || exit 1
export CUDA_HOME=$(spack location -i cuda@12.9.1)

export PATH=$HPCX/ompi/bin:$PATH
export LD_LIBRARY_PATH=$DFTFE_DEPS_DIR/lib:$DFTFE_DEPS_DIR/lib64:$DFTFE_ELPA_DIR/lib:$HPCX/ompi/lib:$HPCX/ucx/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=$SYSROOT/usr/lib64:$DFTFE_DEPS_DIR/lib:$DFTFE_DEPS_DIR/lib64:$DFTFE_ELPA_DIR/lib:$LIBRARY_PATH
export COMPILER_PATH=$SYSROOT/usr/lib64:$COMPILER_PATH
export CPATH=$SYSROOT/usr/include:$CPATH
export CMAKE_INCLUDE_PATH=$STACK/sysroot-shim
export CMAKE_LIBRARY_PATH=$SYSROOT/usr/lib64
export PATH=$STACK/toolchain-wrappers:$PATH

cd "$SLURM_SUBMIT_DIR" || exit 1
for f in install_dftfe.sh "$DFTFE_SYSROOT_INC/stdio.h" "$STACK/sysroot-shim/dlfcn.h" \
         "$STACK/toolchain-wrappers/mpicxx" "$HPCX/ompi/bin/mpicxx"; do
  [ -e "$f" ] || { echo "ERROR: $f not found (see README.md)"; exit 1; }
done
if [ "$STAGES" != "--dftfe" ]; then
  case "$(readlink -f "$DFTFE_DEPS_DIR") $(readlink -f "$DFTFE_ELPA_DIR")" in
    *"$(readlink -f $PREBUILT)/install_DFTFE/"*)
      echo "ERROR: $PREBUILT is shared; build dependencies under your own STACK (see README.md)"
      exit 1 ;;
  esac
fi
if [[ "$STAGES" == *--dftfe* ]] && [ -z "$(ls -A "dftfe_$BRANCH/src" 2>/dev/null)" ]; then
  echo "ERROR: dftfe_$BRANCH/src is empty; clone DFT-FE there on the login node (see README.md)"
  exit 1
fi

bash ./install_dftfe.sh $STAGES --branch=$BRANCH --nprocs=44
rc=$?
echo "install_dftfe.sh exit=$rc"
exit $rc
