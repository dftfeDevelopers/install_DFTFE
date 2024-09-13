module load cpe/24.07
module load PrgEnv-gnu/8.5.0
module load craype-accel-amd-gfx90a
module load rocm
module load openblas
module load cmake
module load boost/1.85.0
module unload cray-libsci

export MPICH_GPU_SUPPORT_ENABLED=1

export WD=/lustre/orion/mat295/scratch/dsambit/install_DFTFE
export INST=$WD/env2

export LD_LIBRARY_PATH=$CRAY_LD_LIBRARY_PATH:$LD_LIBRARY_PATH

