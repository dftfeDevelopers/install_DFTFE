# Install DFT-FE

These install scripts provide a set of executable
functions that install the necessary dependencies
of [DFT-FE](https://github.com/dftfeDevelopers/dftfe)
on NERSC Perlmutter.

To use these scripts, we assume you have cloned this
repository onto a system where you intend to install DFT-FE.
For example, I installed it into `$PSCRATCH/DFT-FE` after 
cloning into the scratch directory

    cd $PSCRATCH
    git clone https://github.com/dsambit/install_DFT-FE.git DFT-FE
    cd DFT-FE

## Pre-requisites

Because it's a better shell, the scripts are written
in the [rc](http://doc.cat-v.org/plan_9/4th_edition/papers/rc)
shell language.  Install `rc` by running

    cp src/rcrc $HOME/.rcrc
    . ./bin/getrc.sh $HOME/$LMOD_SYSTEM_NAME
    rc -l

Note that getrc installs into the `$HOME/$LMOD_SYSTEM_NAME/bin`
directory, and adds that to your PATH.

Copying the rcrc startup file to your home directory provides
the module command (in case your lmod version is old,
and doesn't yet recognize the rc shell).

## Module Environment

The module environment intended to run DFT-FE has been extracted
into `env2/env.rc`.  Edit this file before proceeding any further.
Make sure that your module environment contains some version of the
pre-requisites mentioned there (e.g. python3 and openblas).
This environment file is used both by the install and run
phases of DFT-FE.

## Running the installation
The installation itself is contained within the functions in
`dftfe2.rc`.  Edit this to define its WD and INST directories
to reflect your own environment.
Then source this script using

    . ./dftfe2.rc

and then run the functions listed in that file manually, in order.
For example, 

    install_blis
    install_libflame
    install_alglib
    install_libxc
    install_spglib
    install_p4est
    install_scalapack
    install_elpa
    install_dealii
    install_dftd4 #(optional)
    compile_dftfe

Each function follows a standard pattern - download source into `$WD/src`,
patch, compile, and install into `$INST`.  It is HIGHLY recommended
to check all warnings and errors from these installs to be sure
you have not ended up with broken packages.


## Running DFT-FE

DFT-FE is built in real and cplx versions, depending on whether you
want to enable k-points (implemented in the cplx version only).

Assuming you have already sourced `env2/env.rc`, an example
batch script running GPU-enabled DFT-FE on 2 nodes is below:

 #!/usr/bin/env rc
 #SBATCH -A m2360_g
 #SBATCH -C gpu
 #SBATCH -q regular
 #SBATCH --job-name Be_test_dftfe
 #SBATCH -t 00:10:00
 #SBATCH -n 8
 #SBATCH --ntasks-per-node=4
 #SBATCH -c 32
 #SBATCH --gpus-per-node=4
 #SBATCH --gpu-bind=map_gpu:0,1,2,3

 SLURM_CPU_BIND='cores'
 OMP_NUM_THREADS=1

 LD_LIBRARY_PATH = $LD_LIBRARY_PATH:$WD/env2/lib
 LD_LIBRARY_PATH = $LD_LIBRARY_PATH:$WD/env2/lib64
 BASE = $WD/src/dftfe/build/release/real

 srun  $BASE/dftfe parameterFile.prm > output
