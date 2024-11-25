Set environment variables for WD (work directory where build happens)
and INST (installation directory) 
# Install DFT-FE dependencies
    source ./dftfeInstall.sh
    install_alglib
    install_libxc
    install_spglib
    install_p4est
    install_elpa
    install_kokkos
    install_dealii

# Install DFT-FE
    compile_dftfe

## Running DFT-FE

DFT-FE is built in real and cplx versions, depending on whether you
want to enable k-points (implemented in the cplx version only).
real executable: $WD/src/dftfe\_"branchname"/build/release/real/dftfe
complex executable: $WD/src/dftfe\_"branchname"/build/release/complex/dftfe
