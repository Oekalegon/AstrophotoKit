# Setting Up CFITSIO

This package uses CFITSIO (the official C library for FITS file handling) to provide fast and reliable FITS file support.

## Quick Setup

To integrate CFITSIO into this package, you need to download the CFITSIO source code:

### Option 1: Download and Extract (Recommended)

1. Download CFITSIO from the official source:
   - Visit: https://heasarc.gsfc.nasa.gov/fitsio/
   - Or use: https://github.com/HEASARC/cfitsio/releases
   - Download the latest release (e.g., `cfitsio-4.x.x.tar.gz`)

2. Extract the archive:
   ```bash
   cd AstrophotoKit/Sources/CAstrophotoKit
   tar -xzf /path/to/cfitsio-4.x.x.tar.gz
   mv cfitsio-4.x.x cfitsio
   ```

### Option 2: Git Submodule

If you're using Git, you can add CFITSIO as a submodule:

```bash
cd AstrophotoKit/Sources/CAstrophotoKit
git submodule add https://github.com/HEASARC/cfitsio.git cfitsio
```

## Verify Setup

After adding CFITSIO, verify the structure:

```
AstrophotoKit/
└── Sources/
    └── CAstrophotoKit/
        ├── module.modulemap
        └── cfitsio/
            ├── fitsio.h
            ├── fitsio2.h
            └── ... (other CFITSIO source files)
```

## Build

Once CFITSIO is in place, build the package:

```bash
swift build
```

## License

CFITSIO is distributed under its own license. Please review the license terms in the CFITSIO distribution to ensure compliance with your project's requirements.

