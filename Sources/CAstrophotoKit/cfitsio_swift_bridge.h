#ifndef CFITSIO_SWIFT_BRIDGE_H
#define CFITSIO_SWIFT_BRIDGE_H

// Opaque pointer type - actual definition in fitsio.h
// Using void* here and casting in implementation
typedef void CFITSFile;

#ifdef __cplusplus
extern "C" {
#endif

// Wrapper functions for CFITSIO macros so Swift can call them
// These must be declared here (standalone, no includes) for Swift to see them
int fits_open_file_wrapper(CFITSFile **fptr, const char *filename, int mode, int *status);
int fits_close_file_wrapper(CFITSFile *fptr, int *status);
int fits_get_num_hdus_wrapper(CFITSFile *fptr, int *numhdus, int *status);
int fits_movabs_hdu_wrapper(CFITSFile *fptr, int hdunum, int *hdutype, int *status);
int fits_get_hdrspace_wrapper(CFITSFile *fptr, int *nexist, int *nmore, int *status);
int fits_read_keyn_wrapper(CFITSFile *fptr, int nkey, char *keyname, char *value, char *comment, int *status);
int fits_get_img_param_wrapper(CFITSFile *fptr, int maxdim, int *bitpix, int *naxis, long long *naxes, int *status);
int fits_read_img_wrapper(CFITSFile *fptr, int datatype, long long *fpixel, long long *nelements, void *nulval, void *array, int *anynul, int *status);
void fits_get_errstatus_wrapper(int status, char *err_text);

#ifdef __cplusplus
}
#endif

#endif /* CFITSIO_SWIFT_BRIDGE_H */

