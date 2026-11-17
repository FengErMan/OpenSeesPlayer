/* Symbol aliases for Windows MinGW/gfortran builds of OpenSees. */
#if !defined(__x86_64__) && !defined(__i386__)
  #error "Unsupported architecture for symbol_alias.S"
#endif

.macro ALIAS upper, lower
    .text
    .globl \upper
    .def \upper; .scl 2; .type 32; .endef
\upper:
    jmp \lower
.endm

/* LAPACK / BLAS */
ALIAS DGBSV,  dgbsv_
ALIAS DGBTRS, dgbtrs_
ALIAS DGEEV,  dgeev_
ALIAS DGELS,  dgels_
ALIAS DGESV,  dgesv_
ALIAS DGETRF, dgetrf_
ALIAS DGETRI, dgetri_
ALIAS DGETRS, dgetrs_
ALIAS DGGEV,  dggev_
ALIAS DPBSV,  dpbsv_
ALIAS DPBTRS, dpbtrs_
ALIAS DPOTRF, dpotrf_
ALIAS DSBEVX, dsbevx_
ALIAS DTRSV,  dtrsv_
ALIAS DTRTRS, dtrtrs_

/* ARPACK */
ALIAS DSAUPD, dsaupd_
ALIAS DSEUPD, dseupd_

/* OpenSees Fortran routines */
ALIAS PML_2D,   pml_2d_
ALIAS PML_3D,   pml_3d_
ALIAS STEEL,    steel_
ALIAS STEELDR,  steeldr_
ALIAS COMPR14,  compr14_
ALIAS TENSI14,  tensi14_
ALIAS FILL00,   fill00_
ALIAS GET00,    get00_
ALIAS RESP00,   resp00_
ALIAS STIF00,   stif00_
ALIAS SDMUC,    sdmuc_
ALIAS MYGENMMD, mygenmmd_
