#include "fitsio_wrapper.h"
// Note: cfitsio_swift_bridge.h uses struct fitsfile, but after including fitsio_wrapper.h,
// fitsfile is a typedef, so we need to cast or use the typedef
#include "cfitsio_swift_bridge.h"

// Wrapper functions for CFITSIO macros so Swift can call them

int fits_open_file_wrapper(CFITSFile **fptr, const char *filename, int mode, int *status) {
    return fits_open_file((fitsfile **)fptr, filename, mode, status);
}

int fits_close_file_wrapper(CFITSFile *fptr, int *status) {
    return fits_close_file((fitsfile *)fptr, status);
}

int fits_get_num_hdus_wrapper(CFITSFile *fptr, int *numhdus, int *status) {
    return fits_get_num_hdus((fitsfile *)fptr, numhdus, status);
}

int fits_movabs_hdu_wrapper(CFITSFile *fptr, int hdunum, int *hdutype, int *status) {
    return fits_movabs_hdu((fitsfile *)fptr, hdunum, hdutype, status);
}

int fits_get_hdrspace_wrapper(CFITSFile *fptr, int *nexist, int *nmore, int *status) {
    return fits_get_hdrspace((fitsfile *)fptr, nexist, nmore, status);
}

int fits_read_keyn_wrapper(CFITSFile *fptr, int nkey, char *keyname, char *value, char *comment, int *status) {
    return fits_read_keyn((fitsfile *)fptr, nkey, keyname, value, comment, status);
}

int fits_get_img_param_wrapper(CFITSFile *fptr, int maxdim, int *bitpix, int *naxis, long long *naxes, int *status) {
    long naxes_long[3];
    int result = fits_get_img_param((fitsfile *)fptr, maxdim, bitpix, naxis, naxes_long, status);
    // Convert long to long long
    for (int i = 0; i < 3; i++) {
        naxes[i] = (long long)naxes_long[i];
    }
    return result;
}

int fits_read_img_wrapper(CFITSFile *fptr, int datatype, long long *fpixel, long long *nelements, void *nulval, void *array, int *anynul, int *status) {
    return fits_read_img((fitsfile *)fptr, datatype, *fpixel, *nelements, nulval, array, anynul, status);
}

void fits_get_errstatus_wrapper(int status, char *err_text) {
    fits_get_errstatus(status, err_text);
}

