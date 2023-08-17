# Install DFT-FE

These install scripts provide a set of executable
functions that install the necessary dependencies
of [DFT-FE](https://github.com/dftfeDevelopers/dftfe) on UMICH Greatlakes.

To use the script, we assume you have cloned this
repository onto a system where you intend to install DFT-FE.
For example, I installed it into `$myscratch/install_DFTFE` after 
cloning into the scatch directory

    cd $myscratch
    git clone https://github.com/dftfeDevelopers/install_DFTFE.git install_DFTFE
    cd install_DFTFE
    git checkout greatlakesScript

## Pre-requisites

Because it's a better shell, the scripts are written
in the [rc](http://doc.cat-v.org/plan_9/4th_edition/papers/rc)
shell language.  Install `rc` by running

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
The installation itself is contained within the functions in
`dftfe2.rc`.  Log into an **interactive 1 node job (CAUTION:without interactive job the
compilation process will crash)** on greatlakes and source this script using

    . ./dftfe2.rc

and then run the functions listed in that file manually, in order.
For example, 

    install_alglib
    install_libxc
    install_spglib
    install_p4est
    install_scalapack
    install_elpa
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

Assuming you have already sourced `env2/env.rc`, an example
batch script running DFT-FE on 1 node is below:

    #!$HOME/$LMOD_SYSTEM_NAME/bin/rc

    #SBATCH --job-name testdftfe
    #SBATCH --nodes=1
    #SBATCH --ntasks-per-node=36
    #SBATCH --mem-per-cpu=5g
    #SBATCH --time=1:00:00
    #SBATCH --account=vikramg1
    
    export OMP_NUM_THREADS=1
    mpirun -n 36 dftfe parameters.prm > output



