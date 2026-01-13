#ifndef FITSIO_WRAPPER_H
#define FITSIO_WRAPPER_H

// Define HAVE_UNION_SEMUN before including fitsio headers
// This prevents CFITSIO from redefining semun which is already defined in macOS
#define HAVE_UNION_SEMUN 1

// Undefine HAVE_SHMEM_SERVICES to prevent inclusion of drvrsmem.h
// which causes semun redefinition conflicts on macOS
#ifdef HAVE_SHMEM_SERVICES
#undef HAVE_SHMEM_SERVICES
#endif

// Include the main FITSIO headers
#include "cfitsio/fitsio.h"
#include "cfitsio/fitsio2.h"
#include "cfitsio/longnam.h"

#endif /* FITSIO_WRAPPER_H */

