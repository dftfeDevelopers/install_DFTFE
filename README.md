# Install DFT-FE

These install scripts provide a set of executable
functions that install the necessary dependencies
of [DFT-FE](https://github.com/dftfeDevelopers/dftfe) on OLCF Frontier machine.

To use these scripts, we assume you have cloned this
repository onto a system where you intend to install DFT-FE.
For example, I installed it into `/lustre/orion/[projid]/scratch/$USER/install_DFTFE` after 
cloning into the scatch directory

    cd /lustre/orion/[projid]/scratch/$USER
    git clone https://github.com/dftfeDevelopers/install_DFTFE.git install_DFTFE
    cd install_DFTFE
    git checkout frontierScriptROCM6Dealii9.5.2



## Module Environment

The module environment intended to run DFT-FE has been extracted
into `env2/env.sh`.  Edit this file before proceeding any further.
Make sure that your module environment contains some version of the
pre-requisites mentioned there (e.g. python3 and openblas).
This environment file is used both by the install and run
phases of DFT-FE.

## Running the installation
The installation itself is contained within the functions in
`dftfe2.sh`.  Source this script using

    . ./dftfe2.sh

and then run the functions listed in that file manually, in order.
For example, 

    install_alglib
    install_libxc
    install_spglib
    install_p4est
    install_scalapack
    install_ofi_rccl (optional)
    install_elpa
    install_kokkos
    install_dealii
    install_dftd4 (optional)
    compile_dftfe

Each function follows a standard pattern - download source into `$WD/src`,
patch, compile, and install into `$INST`.  It is HIGHLY recommended
to check all warnings and errors from these installs to be sure
you have not ended up with broken packages.


## Running DFT-FE

DFT-FE is built in real and cplx versions, depending on whether you
want to enable k-points (implemented in the cplx version only).

An example batch script running GPU-enabled DFT-FE on 280 nodes is below:

    #!/bin/bash
    #SBATCH -A spy007
    #SBATCH -J dft14584
    #SBATCH -t 00:25:00
    #SBATCH -p batch
    #SBATCH -N 280
    #SBATCH --gpus-per-node 8
    #SBATCH --ntasks-per-gpu 1
    #SBATCH --gpu-bind closest

    export OMP_NUM_THREADS = 1
    export MPICH_VERSION_DISPLAY=1
    export MPICH_ENV_DISPLAY=1
    export MPICH_OFI_NIC_POLICY = NUMA 
    export MPICH_GPU_SUPPORT_ENABLED=1
    export MPICH_SMP_SINGLE_COPY_MODE=NONE

    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$INST/lib
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$INST/lib/lib64
    export LD_LIBRARY_PATH=$CRAY_LD_LIBRARY_PATH:$LD_LIBRARY_PATH


    export BASE = $WD/src/dftfe/build/release/real
    export n=`{echo $SLURM_JOB_NUM_NODES '*' 8 | bc}

    srun -n $n -c 7 --gpu-bind closest \
              $BASE/dftfe parameterFileGPU.prm > output

This uses `SLURM_JOB_NUM_NODES` to compute the number of MPI
ranks to use as one per GCD (8 per node).  If you wish to run
on a different number of nodes, only the `#SBATCH -N 280`
needs to be changed.
