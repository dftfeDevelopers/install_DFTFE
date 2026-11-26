# DFT-FE environment for ALCF Polaris. Sourced by install_dftfe.sh; source it in job scripts too.
module reset
module unload darshan
module use /soft/modulefiles
module load PrgEnv-gnu/8.7.0 gcc-native/14
module load cuda/13.0
module load craype-x86-milan craype-accel-nvidia80
module load spack-pe-base cmake

export DFTFE_PREFIX=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export DFTFE_DEPS=$DFTFE_PREFIX/dependencies

export CUDA_MATH_HOME=$(realpath -m "$CUDA_HOME/../../math_libs/13.0")
export NCCL_ROOT=$(realpath -m "$CUDA_HOME/../../comm_libs/13.0/nccl")
export NCCL_INCLUDE_DIR=$NCCL_ROOT/include
export NCCL_LIB_DIR=$NCCL_ROOT/lib

export PATH=$DFTFE_DEPS/bin:$PATH
export LD_LIBRARY_PATH=$DFTFE_DEPS/lib:$CUDA_MATH_HOME/lib64:$NCCL_LIB_DIR:/soft/libraries/hwloc/lib:$LD_LIBRARY_PATH
export MPICH_GPU_SUPPORT_ENABLED=1
export PYTHON=python3
export CMAKE_POLICY_VERSION_MINIMUM=3.5
export FI_CXI_DISABLE_HOST_REGISTER=1
export FI_MR_CACHE_MONITOR=userfaultfd
export FI_CXI_DEFAULT_CQ_SIZE=131072

awsOfiNccl=/soft/libraries/aws-ofi-nccl/v1.9.1-aws/lib
if [[ -f $awsOfiNccl/libnccl-net.so &&
      $(LD_LIBRARY_PATH=$awsOfiNccl:$LD_LIBRARY_PATH ldd $awsOfiNccl/libnccl-net.so) != *"not found"* ]]; then
  export LD_LIBRARY_PATH=$awsOfiNccl:$LD_LIBRARY_PATH
  export NCCL_NET_GDR_LEVEL=PHB NCCL_CROSS_NIC=1 NCCL_COLLNET_ENABLE=1 NCCL_NET="AWS Libfabric"
fi
