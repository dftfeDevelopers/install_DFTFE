# Install DFT-FE on Polaris
Bash script to build [DFT-FE](https://github.com/dftfeDevelopers/dftfe) and its dependencies on the **ALCF Polaris** supercomputer.

Clone the repository where DFT-FE should be installed, for example `$MYPROJECTDIR/install_DFTFE`:
```bash
cd "$MYPROJECTDIR"
git clone https://github.com/dftfeDevelopers/install_DFTFE.git install_DFTFE
cd install_DFTFE
git checkout polarisScript
chmod +x install_dftfe.sh
```
Everything is installed in this directory: the dependencies in `dependencies/`, DFT-FE in `dftfe_<branch>/` and the build logs in `logs/`.

## Installation
Install on a compute node with the job script `compile_script.sub`, which runs `./install_dftfe.sh --all`:
```bash
qsub compile_script.sub
```
You can also run `./install_dftfe.sh [options]` directly; on a login node, keep `--nprocs` small. Options:
```bash
--download          | Download the dependencies and clone DFT-FE
--build             | Build the dependencies and DFT-FE
--all               | --download and --build
--branch=NAME       | DFT-FE branch, the same for downloading and building. Default: publicGithubDevelop
--repo=URL          | DFT-FE repository. Default: https://github.com/dftfeDevelopers/dftfe.git
--nprocs=N          | Number of parallel build jobs. Default: 8
--clean-build-files | Remove the unpacked sources after building (the downloaded archives are kept)
```
To build only some packages, give them instead of `--build`:
```bash
--alglib --libxc --spglib --libxml2 --numdiff --p4est --kokkos --boost --dealii --elpa --dftd --dftfe
```
`--dftd` builds DFT-D3 and DFT-D4. It is optional and not part of `--build` or `--all`.

Package versions and DFT-FE options are set in `install_dftfe.sh`:
- `withHigherQuadPSP` and `minimalCompile` are for DFT-FE branches not yet up to date with `publicGithubDevelop`.
- `elpaWithOpenMP=ON` builds ELPA with OpenMP; `OFF` builds it with NCCL.

### deal.II 9.8
`IndexSet::fill_index_vector()` works up to deal.II 9.7, with a deprecation notice since 9.5, and was removed in deal.II 9.8. Its replacement, `IndexSet::get_index_vector()`, exists since 9.5, and DFT-FE requires deal.II 9.5.1 or newer, so DFT-FE branches should use `get_index_vector()`. Branches that still call `fill_index_vector()` need deal.II 9.7.1.

## Running DFT-FE
The executables are `dftfe_<branch>/install/real/dftfe` and `dftfe_<branch>/install/complex/dftfe`. Use the complex one for k-points. Source `dftfe_env_polaris.sh` in job scripts, so that DFT-FE runs with the modules it was built with. Example PBS job script:
```bash
#!/bin/bash -l
#PBS -l select=4:system=polaris
#PBS -l place=scatter
#PBS -l walltime=00:59:59
#PBS -l filesystems=home:eagle
#PBS -q debug-scaling
#PBS -A DFTCalculations
#PBS -e error.log
#PBS -o output.log

source $MYPROJECTDIR/install_DFTFE/dftfe_env_polaris.sh
cd ${PBS_O_WORKDIR}

NNODES=`wc -l < $PBS_NODEFILE`
NRANKS_PER_NODE=$(nvidia-smi -L | wc -l)
NDEPTH=8
NTHREADS=8
export DFTFE_NUM_THREADS=8
NTOTRANKS=$(( NNODES * NRANKS_PER_NODE ))

exe=$MYPROJECTDIR/install_DFTFE/dftfe_publicGithubDevelop/install/real/dftfe
mpiexec -n ${NTOTRANKS} --ppn ${NRANKS_PER_NODE} --depth=${NDEPTH} --cpu-bind depth --env OMP_NUM_THREADS=${NTHREADS} -env OMP_PLACES=threads ./set_affinity_gpu_polaris.sh $exe parameterFileGPU.prm > output
```
