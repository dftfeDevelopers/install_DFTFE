# Install DFT-FE on PARAM Rudra
Install script and Slurm job script for building [DFT-FE](https://github.com/dftfeDevelopers/dftfe) on the **PARAM Rudra** supercomputer (CDAC, 2x NVIDIA A100 80GB per GPU node).

A validated dependency stack is already installed on the machine. Most users only need to build DFT-FE against it, which takes 10 to 15 minutes. Building the dependencies yourself is described in the last sections.

# Prebuilt dependencies on PARAM Rudra
Root: `/home/nsmext/phanim.iisc/dftfe` (readable by all users; do not build into it).

| Directory | Contents |
|---|---|
| `install_DFTFE/dependencies/` | All libraries below except ELPA 2026 (`lib/`, `lib64/`, `include/`, `bin/`; source tarballs in `src/`) |
| `install_DFTFE/elpa-2026.02.002/` | ELPA 2026.02.002 |
| `hpcx-gcc13/` | Open MPI (`ompi/`) and UCX (`ucx/`) |
| `sysroot/` | `/usr/include` and `/usr/lib64` copied from a login node, for compiling on compute nodes |
| `sysroot-shim/` | `dlfcn.h` only, for CMake's `find_path` |
| `toolchain-wrappers/` | `gcc`, `g++`, `gfortran`, `mpicc`, `mpicxx`, `mpif90`, `mpifort`; each calls the real compiler with `-idirafter sysroot/usr/include` |

| Component | Version | Details |
|---|---|---|
| GCC | 13.4.0 | Spack: `spack load gcc@13.4.0/azyvhui` |
| CUDA | 12.9.1 | Spack: `spack load cuda@12.9.1`; code built for `sm_80` |
| Open MPI | 4.1.9a1 | From the HPC-X v2.25.1 sources, rebuilt with GCC 13.4.0: CUDA, UCX, Slurm, Mellanox platform file |
| UCX | 1.20.0 | From the HPC-X v2.25.1 sources: InfiniBand (`rc_mlx5`, `rdmacm`), CUDA, knem, CMA |
| BLAS/LAPACK | BLIS 1.1, libFLAME 5.2.0 | OpenMP threading |
| ScaLAPACK | 2.2.0 | netlib |
| ELPA | 2026.02.002 | OpenMP, NVIDIA GPU kernels, GPU streams |
| deal.II | 9.6.2 | 64-bit indices, MPI, LAPACK; p4est 2.8.6, Kokkos 4.3.00, Boost 1.86.0 |
| libxc | 6.2.2 | |
| spglib | 2.5.0 | |
| Alglib | 4.04.0 | |
| libxml2 | 2.13.5 | |
| numdiff | 5.9.0 | Used by the DFT-FE tests |

The libraries in `dependencies/` were built with `install_dftfe.sh` from this branch (compiler flags at the top of the script), and ELPA 2026.02.002 with the same configure line. `dependencies/lib` also contains ELPA 2025.06.001, which its developers mark as not to be used. Both versions have the soname `libelpa_openmp.so.19`, so `elpa-2026.02.002/lib` must come before `dependencies/lib` in `LD_LIBRARY_PATH` (see [Running DFT-FE](#running-dft-fe)).

Why the stack is built this way:
- **MPI.** Spack's UCX has no InfiniBand transport, and the precompiled HPC-X on the system is built with GCC 11.5, whose Fortran modules do not mix with GCC 13. UCX and Open MPI are therefore rebuilt from the HPC-X sources with GCC 13.4.0.
- **sysroot and wrappers.** Compute nodes have no glibc headers, so nothing compiles there without the copied headers. Some sub-builds (Boost's `bootstrap.sh`, deal.II's bundled muparser) ignore `CFLAGS`/`CXXFLAGS`, so the include directory is added by compiler wrappers. It is added with `-idirafter`, not `-I`, `-isystem` or `CPATH`, because libstdc++'s `<cstdlib>`, `<cmath>`, ... reach the C headers through `#include_next`, which only searches directories after gcc's own.

The sysroot and the wrappers are needed only for building; running a built binary does not use them.

# Build DFT-FE against the prebuilt dependencies
```bash
git clone -b paramRudraInstall https://github.com/dftfeDevelopers/install_DFTFE.git
cd install_DFTFE
# on the login node: compute nodes have no internet access
git clone -b publicGithubDevelop https://github.com/dftfeDevelopers/dftfe.git dftfe_publicGithubDevelop/src
sbatch compile_script.slurm
```
The job builds `dftfe_publicGithubDevelop/install/real/dftfe` (Gamma point) and `dftfe_publicGithubDevelop/install/complex/dftfe` (k-points); the log is `dftfe-build-<jobid>.out`.
- For another branch or fork, put its source in `dftfe_<name>/src` and submit with `BRANCH=<name> sbatch compile_script.slurm`.
- After changing the source, submit the job again; it rebuilds only what changed.

# Running DFT-FE
Use `mpirun`, or `srun --mpi=pmix`; a plain `srun` launches singleton MPI processes. An example job script for GPU-enabled DFT-FE on 5 nodes (10 GPUs):
```bash
#!/bin/bash
#SBATCH -p gpu-small
#SBATCH -N 5
#SBATCH --ntasks-per-node=48
#SBATCH --gres=gpu:2
#SBATCH --mem=175G
#SBATCH -t 04:00:00
#SBATCH -J dftfe
#SBATCH -o output.log
#SBATCH -e error.log

STACK=/home/nsmext/phanim.iisc/dftfe
exe=/path/to/install_DFTFE/dftfe_publicGithubDevelop/install/real/dftfe   # complex/dftfe for k-points

module load spack
. /home/apps/spack/share/spack/setup-env.sh
spack load gcc@13.4.0/azyvhui
spack load cuda@12.9.1
CUDA_HOME=$(spack location -i cuda@12.9.1)

HPCX=$STACK/hpcx-gcc13
D=$STACK/install_DFTFE/dependencies
ELPA=$STACK/install_DFTFE/elpa-2026.02.002
export PATH=$HPCX/ompi/bin:$PATH
# ELPA 2026 first: the ELPA 2025 in $D/lib has the same soname
export LD_LIBRARY_PATH=$ELPA/lib:$D/lib:$D/lib64:$HPCX/ompi/lib:$HPCX/ucx/lib:$CUDA_HOME/lib64:$LD_LIBRARY_PATH
export OMP_NUM_THREADS=1 DFTFE_NUM_THREADS=1 DEAL_II_NUM_THREADS=1 ELPA_DEFAULT_omp_threads=1
export UCX_TLS=rc_mlx5,ud_mlx5:aux,sm,self,cuda_copy,cuda_ipc UCX_NET_DEVICES=mlx5_0:1 UCX_LOG_LEVEL=ERROR

# one MPI rank per GPU
NRANKS_PER_NODE=$(nvidia-smi -L | wc -l)
NTOTRANKS=$(( SLURM_JOB_NUM_NODES * NRANKS_PER_NODE ))
echo "NUM_OF_NODES= ${SLURM_JOB_NUM_NODES} TOTAL_NUM_RANKS= ${NTOTRANKS} RANKS_PER_NODE= ${NRANKS_PER_NODE}"

mpirun -n ${NTOTRANKS} --map-by ppr:${NRANKS_PER_NODE}:node \
  -x LD_LIBRARY_PATH -x OMP_NUM_THREADS -x DFTFE_NUM_THREADS -x DEAL_II_NUM_THREADS -x ELPA_DEFAULT_omp_threads \
  -x UCX_TLS -x UCX_NET_DEVICES -x UCX_LOG_LEVEL \
  $exe parameterFileGPU.prm > output
```
`ldd $exe | grep elpa` should show `elpa-2026.02.002/lib`.

# Building the dependencies yourself
Only needed for other versions or a separate stack. Choose a root directory; everything is installed under it in the layout above.

**1. Login node: MPI, sysroot and compiler wrappers**

Link the prebuilt ones:
```bash
export STACK=$HOME/dftfe
mkdir -p $STACK
for d in hpcx-gcc13 sysroot sysroot-shim toolchain-wrappers; do
  ln -sfn /home/nsmext/phanim.iisc/dftfe/$d $STACK/$d
done
```
or make your own (needed if you rebuild MPI):
```bash
export STACK=$HOME/dftfe
module load spack
. /home/apps/spack/share/spack/setup-env.sh
spack load gcc@13.4.0/azyvhui
spack load cuda@12.9.1
export CUDA_HOME=$(spack location -i cuda@12.9.1)

S=$STACK/sysroot
mkdir -p $S/usr
cp -a /usr/include /usr/lib64 $S/usr/
chmod -R u+w $S
ln -sfn usr/lib64 $S/lib64
# ELPA links with -lhwloc, and /usr/lib64 has no libhwloc.so development link
[ -e $S/usr/lib64/libhwloc.so ] || ln -s libhwloc.so.15 $S/usr/lib64/libhwloc.so
mkdir -p $STACK/sysroot-shim
cp $S/usr/include/dlfcn.h $STACK/sysroot-shim/

# MPI: link the prebuilt one unless you rebuilt it (next section)
[ -e $STACK/hpcx-gcc13 ] || ln -s /home/nsmext/phanim.iisc/dftfe/hpcx-gcc13 $STACK/hpcx-gcc13

W=$STACK/toolchain-wrappers
mkdir -p $W
for c in gcc g++ gfortran; do
  printf '#!/bin/bash\nexec "%s" -idirafter "%s" "$@"\n' "$(which $c)" $S/usr/include > $W/$c
done
for c in mpicc mpicxx mpif90 mpifort; do
  printf '#!/bin/bash\nexec "%s" -idirafter "%s" "$@"\n' $STACK/hpcx-gcc13/ompi/bin/$c $S/usr/include > $W/$c
done
chmod +x $W/*
```

**2. Login node: sources**
```bash
cd $STACK
git clone -b paramRudraInstall https://github.com/dftfeDevelopers/install_DFTFE.git
cd install_DFTFE
./install_dftfe.sh --download    # dependency tarballs and DFT-FE; add --branch=<name> for another branch
```

**3. Compute nodes: dependencies (about 20 minutes), then DFT-FE, as two jobs within the 1 h limit of the debug partition**
```bash
DEPS="--blaslapack --scalapack --alglib --spglib --libxml2 --numdiff --libxc --p4est --kokkos --boost --dealii --elpa"
j=$(STAGES="$DEPS" sbatch --parsable compile_script.slurm)
sbatch --dependency=afterok:$j compile_script.slurm
```
`compile_script.slurm` reads `STACK` from the environment and refuses to build dependencies into the shared prebuilt stack.

## Rebuilding Open MPI and UCX
Build on the login node, where UCX finds the InfiniBand headers, with GCC 13.4.0 and CUDA 12.9.1 loaded as in step 1, before making the wrappers. The sources are in the `sources/` directory of HPC-X v2.25.1; copies are in `/home/nsmext/phanim.iisc/dftfe-recipe/hpcx-sources/`.
```bash
P=$STACK/hpcx-gcc13
SRC=/home/nsmext/phanim.iisc/dftfe-recipe/hpcx-sources
KNEM=/opt/knem-1.1.4.90mlnx3
mkdir -p $P/build && cd $P/build
tar xf $SRC/ucx-1.20.0.tar.gz && cd ucx-1.20.0
./configure --prefix=$P/ucx --with-cuda=$CUDA_HOME --with-knem=$KNEM --enable-mt --enable-optimizations \
  --disable-logging --disable-debug --disable-assertions --disable-params-check --without-java --without-go \
  --enable-shared --disable-static
make -j 8 && make install && cd ..
tar xf $SRC/openmpi-gitclone.tar.gz && cd openmpi-gitclone
./configure --prefix=$P/ompi --with-libevent=internal --enable-mpi1-compatibility --without-xpmem \
  --with-cuda=$CUDA_HOME --with-slurm --with-platform=contrib/platform/mellanox/optimized \
  --with-ucx=$P/ucx --with-knem=$KNEM --enable-mpi-fortran --enable-shared
make -j 8 && make install
```

## install_dftfe.sh options
`install_dftfe.sh` installs into the directory it is run from (`dependencies/`, `dftfe_<branch>/`). `compile_script.slurm` passes the options in `STAGES` (default `--dftfe`).
```bash
--download          | Download the dependency sources and DFT-FE (login node only)
--all               | --download, then build all dependencies and DFT-FE (login node only)
--branch=$BRANCH    | DFT-FE branch to download or compile (default: publicGithubDevelop);
                    | use the same branch with --download, --all and --dftfe
--nprocs=N          | Number of parallel build tasks (default: 44)
--clean-build-files | Remove all source and build files after compilation
--blaslapack, --scalapack, --alglib, --spglib, --libxml2, --numdiff,
--libxc, --p4est, --kokkos, --boost, --dealii, --elpa
                    | Build one dependency (sources from --download)
--dftfe             | Build DFT-FE (real and complex) for --branch
```
Environment variables:
```bash
DFTFE_DEPS_DIR      | Dependency tree to build into or against (default: ./dependencies)
DFTFE_ELPA_DIR      | ELPA prefix to build into or against (default: DFTFE_DEPS_DIR)
DFTFE_SYSROOT_INC   | Header directory added with -idirafter (default: $HOME/dftfe/sysroot/usr/include)
```

# Notes on PARAM Rudra
- Compute nodes have no internet access: download sources on a login node.
- `debug` is the only CPU partition that accepts a 1-node job (1 h limit). `terai`, `shiwalik`, `hm-small` and the others require at least 10 nodes, so a 1-node build never starts there.
- Two Spack packages match `gcc@13.4.0`, and `spack load gcc@13.4.0` fails with "matches multiple packages". Use `gcc@13.4.0/azyvhui`.
- Request `--mem=175G`. The default of 20 GB per node is too little to build DFT-FE (about 40 GB), and `--mem=0` exceeds the 180 GB per-node limit, so such a job never starts.
- GPU partitions: `gpu-debug` 1-2 nodes, 1 h; `gpu-small` 5-25 nodes, 24 h; `gpu-large` 26-100 nodes, 12 h; `gpu-massive` 101-200 nodes, 6 h.
- Some GPU nodes show only one GPU although Slurm advertises two. Before long runs, check every node with `srun --ntasks-per-node=1 nvidia-smi -L`.
