# Install DFT-FE on Polaris

This repository provides a **bash-based install script** to build [DFT-FE](https://github.com/dftfeDevelopers/dftfe) and its dependencies on the **ALCF Polaris** supercomputer.
To use this script, clone the repository on the system where you plan to install DFT-FE. For example, to install into `$MYPROJECTDIR/install_DFTFE`:

```bash
cd "$MYPROJECTDIR"
git clone https://github.com/dftfeDevelopers/install_DFTFE.git install_DFTFE
cd install_DFTFE
git checkout polarisScript
```
# Pre-requisites

Because it's a better shell, the scripts are written in the [rc](http://doc.cat-v.org/plan_9/4th_edition/papers/rc) shell language.  Install `rc` by running

    export LMOD_SYSTEM_NAME=polaris
    module load PrgEnv-gnu
    module unload craype-accel-nvidia80
    cp src/rcrc $HOME/.rcrc
    . ./bin/getrc.sh $HOME/$LMOD_SYSTEM_NAME
    rc -l

Note that getrc installs into the `$HOME/$LMOD_SYSTEM_NAME/bin`
directory, and adds that to your PATH. Also note that in rc shell, the 
`export` keyword is not used when setting environment variables.

Copying the rcrc startup file to your home directory provides
the module command (in case your lmod version is old,
and doesn't yet recognize the rc shell).

## Module Environment

The module environment intended to run DFT-FE has been extracted
into `env2/env.rc`.  Edit this file before proceeding any further.
Make sure that your module environment contains some version of the
pre-requisites mentioned there.
This environment file is used both by the install and run
phases of DFT-FE.

## Running the installation

./install_dftfe.sh [OPTIONS]

```bash
--branch=$BRANCH    | Optional: Specify the DFT-FE branch to download or compile. If provided, the
                    | same branch must be used consistently with --download, --all, or --dftfe.
                    | Default: `publicGithubDevelop`.
--nprocs=N          | Optional: Set the number of parallel tasks for compilation. Default: 2.

--download          | Download all required dependencies and the DFT-FE
--all               | Download and install all dependencies and DFT-FE
--clean-build-files | Remove all source and build files after compilation
```
After downloading dependencies and DFT-FE source, you can install dependencies and DFT-FE individually (if not using --all):
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
--dftfe | Compile and install DFT-FE branch specified by `--branch` (default `publicGithubDevelop`))
```

## Running DFT-FE

DFT-FE is built in real and cplx versions, depending on whether you
want to enable k-points (implemented in the cplx version only).

An example PBS job submission script running GPU-enabled DFT-FE on 1 nodes is given below after copying
the appropriate:

    #!/bin/bash -l
    #PBS -l select=1:system=polaris
    #PBS -l place=scatter
    #PBS -l walltime=0:30:00
    #PBS -l filesystems=home:grand
    #PBS -q debug
    #PBS -A QuantMatManufact
    #PBS -N myjob

    #Enable GPU-MPI (if supported by application) and load required modules (should be similar to env2/env.rc)
    #export MPICH_GPU_SUPPORT_ENABLED=1
    module load PrgEnv-gnu
    module load nvhpc-mixed
    module unload cray-libsci
    WD=/lus/grand/projects/QuantMatManufact/dsambit/install_DFTFE
    BASE=$WD/src/dftfe/build/release/real

    #Change to working directory
    cd ${PBS_O_WORKDIR}

    #MPI and OpenMP settings
    NNODES=`wc -l < $PBS_NODEFILE`
    NRANKS_PER_NODE=$(nvidia-smi -L | wc -l)
    NDEPTH=8
    NTHREADS=1

    NTOTRANKS=$(( NNODES * NRANKS_PER_NODE ))
    #echo "NUM_OF_NODES= ${NNODES} TOTAL_NUM_RANKS= ${NTOTRANKS} RANKS_PER_NODE= ${NRANKS_PER_NODE} THREADS_PER_RANK= ${NTHREADS}"

    #For applications that internally handle binding MPI/OpenMP processes to GPUs
    mpiexec -n ${NTOTRANKS} --ppn ${NRANKS_PER_NODE} --depth=${NDEPTH} --cpu-bind depth --env OMP_NUM_THREADS=${NTHREADS} -env OMP_PLACES=threads $BASE/dftfe parameterFile_a.prm > output

   
Note that the above job submission is performed in the default `bash` shell although the installation was performed using the `rc` shell. The correct `rc` shell enviroment from `env2/env.rc` is used in the above PBS script. To modify number of nodes change the option in `PBS -l select=1`.
