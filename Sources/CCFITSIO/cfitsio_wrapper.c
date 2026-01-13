#include "shim.h"

// Wrapper functions for cfitsio to bridge Swift and C
// These functions are called from Swift using @_silgen_name

int fits_open_file_wrapper(fitsfile **fptr, const char *filename, int mode, int *status) {
    return fits_open_file(fptr, filename, mode, status);
}

int fits_close_file_wrapper(fitsfile *fptr, int *status) {
    return fits_close_file(fptr, status);
}

int fits_get_num_hdus_wrapper(fitsfile *fptr, int *numhdus, int *status) {
    return fits_get_num_hdus(fptr, numhdus, status);
}

void fits_get_errstatus_wrapper(int status, char *errText) {
    fits_get_errstatus(status, errText);
}

int fits_movabs_hdu_wrapper(fitsfile *fptr, int hduNumber, int *hduType, int *status) {
    return fits_movabs_hdu(fptr, hduNumber, hduType, status);
}

int fits_get_hdrspace_wrapper(fitsfile *fptr, int *numKeys, int *numMore, int *status) {
    return fits_get_hdrspace(fptr, numKeys, numMore, status);
}

int fits_read_keyn_wrapper(fitsfile *fptr, int index, char *keyName, char *value, char *comment, int *status) {
    return fits_read_keyn(fptr, index, keyName, value, comment, status);
}

int fits_get_img_param_wrapper(fitsfile *fptr, int maxDimensions, int *bitpix, int *naxis, LONGLONG *naxes, int *status) {
    return fits_get_img_param(fptr, maxDimensions, bitpix, naxis, naxes, status);
}

int fits_read_img_wrapper(fitsfile *fptr, int dataType, int naxis, LONGLONG *firstPixel, LONGLONG *numElements, float *nullValue, float *array, int *anyNull, int *status) {
    // Convert LONGLONG arrays to long arrays for fits_read_pix
    // fits_read_pix expects long* (32-bit), but we receive LONGLONG* (64-bit) from Swift
    // fits_read_pix is more commonly used and may be more compatible across CFITSIO versions
    long firstPixelLong[3] = {1, 1, 1};  // Default to starting at pixel 1 in each dimension
    long numElementsLong[3] = {1, 1, 1};  // Default values
    
    // Copy only the dimensions that exist (naxis is typically 1, 2, or 3)
    int dimsToCopy = (naxis < 3) ? naxis : 3;
    for (int i = 0; i < dimsToCopy; i++) {
        firstPixelLong[i] = (long)firstPixel[i];
        numElementsLong[i] = (long)numElements[i];
    }
    
    // Calculate total number of elements to read
    long totalElements = 1;
    for (int i = 0; i < dimsToCopy; i++) {
        totalElements *= numElementsLong[i];
    }
    
    // Use fits_read_pix which is more straightforward and widely supported
    // Signature: fits_read_pix(fitsfile *fptr, int datatype, long *fpixel, 
    //                          long nelements, void *nulval, void *array, int *anynul, int *status)
    // fpixel is the starting pixel array [1,1,1...], nelements is total number of pixels to read
    return fits_read_pix(fptr, dataType, firstPixelLong, totalElements, nullValue, array, anyNull, status);
}

