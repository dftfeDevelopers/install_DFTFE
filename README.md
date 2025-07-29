# Install DFT-FE

This install script installs the necessary dependencies
of [DFT-FE](https://github.com/dftfeDevelopers/dftfe) on ALCF Aurora machine.

To use this script the cmake and boost modules need to be loaded

    module load cmake boost ninja

DFT-FE and its dependencies can be installed by running

    chmod +x install_dftfe.sh
    ./install_dftfe.sh --all

Individual dependencies can be installed as follows

    ./install_dftfe.sh --download #downloads DFT-FE and all requried dependencies
    ./install_dftfe.sh --alglib
    ./install_dftfe.sh --spglib
    ./install_dftfe.sh --numdiff
    ./install_dftfe.sh --libxc
    ./install_dftfe.sh --dftd
    ./install_dftfe.sh --p4est
    ./install_dftfe.sh --kokkos
    ./install_dftfe.sh --dealii
    ./install_dftfe.sh --elpa
    ./install_dftfe.sh --dftfe
    
## Running DFT-FE

DFT-FE is built in real and complex versions, depending on whether you
want to enable k-points (implemented in the complex version only).

An example batch script running GPU-enabled DFT-FE on 64 nodes is below:

    #!/bin/bash
    #PBS -l select=64
    #PBS -l place=scatter
    #PBS -l walltime=00:35:00
    #PBS -l filesystems=home
    #PBS -j oe
    #PBS -q prod
    #PBS -A DFTCalc2
    #PBS -N DFTFE_SYCL


    module load boost

    export MPIR_CVAR_ENABLE_GPU=0
    cd $PBS_O_WORKDIR

    NNODES=$(wc -l < "$PBS_NODEFILE")
    NRANKS_PER_NODE=12
    NDEPTH=1
    NTHREADS=1
    NTOTRANKS=$(( NNODES * NRANKS_PER_NODE ))

    echo "Number of Nodes Allocated      = $NNODES"
    echo "Number of Tasks Allocated      = $NTOTRANKS"
    echo "CPU on node                    = $NRANKS_PER_NODE"

    export OMP_NUM_THREADS=1
    export OMP_PLACES=cores
    export DFTFE_NUM_THREADS=1
    export DEAL_II_NUM_THREADS=1

    export CPU_BIND_SCHEME="--cpu-bind=list:1-8:9-16:17-24:25-32:33-40:41-48:53-60:61-68:69-76:77-84:85-92:93-100"
    export GPU_BIND_SCHEME="--gpu-bind=list:0.0:0.1:1.0:1.1:2.0:2.1:3.0:3.1:4.0:4.1:5.0:5.1"

    mpiexec -n ${NTOTRANKS} --ppn ${NRANKS_PER_NODE} ${CPU_BIND_SCHEME} ${GPU_BIND_SCHEME} /lus/flare/projects/DFTCalc2/dftfeDependenciesNew/dftfe/install/real/dftfe parameterFileGPU.prm >"$NNODES"node_noCannon2.out


This uses 12 MPI ranks per node, one rank per tile (12 per node).  If you wish to run
on a different number of nodes, only the `#PBS -l select=64` needs to be changed.
