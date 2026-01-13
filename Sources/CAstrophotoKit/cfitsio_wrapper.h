#ifndef CFITSIO_WRAPPER_H
#define CFITSIO_WRAPPER_H

// Forward declare fitsfile type
struct fitsfile;

#ifdef __cplusplus
extern "C" {
#endif

// Wrapper functions for CFITSIO macros so Swift can call them
int fits_open_file_wrapper(struct fitsfile **fptr, const char *filename, int mode, int *status);
int fits_close_file_wrapper(struct fitsfile *fptr, int *status);
int fits_get_num_hdus_wrapper(struct fitsfile *fptr, int *numhdus, int *status);
int fits_movabs_hdu_wrapper(struct fitsfile *fptr, int hdunum, int *hdutype, int *status);
int fits_get_hdrspace_wrapper(struct fitsfile *fptr, int *nexist, int *nmore, int *status);
int fits_read_keyn_wrapper(struct fitsfile *fptr, int nkey, char *keyname, char *value, char *comment, int *status);
int fits_get_img_param_wrapper(struct fitsfile *fptr, int maxdim, int *bitpix, int *naxis, long long *naxes, int *status);
int fits_read_img_wrapper(struct fitsfile *fptr, int datatype, long long *fpixel, long long *nelements, void *nulval, void *array, int *anynul, int *status);
void fits_get_errstatus_wrapper(int status, char *err_text);

#ifdef __cplusplus
}
#endif

#endif /* CFITSIO_WRAPPER_H */

