#!/bin/bash

# Script to download and set up CFITSIO for AstrophotoKit
# This makes it easy to integrate CFITSIO into the Swift package

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
CFITSIO_DIR="$PACKAGE_DIR/Sources/CAstrophotoKit/cfitsio"

echo "Setting up CFITSIO for AstrophotoKit..."

# Check if CFITSIO is already present
if [ -d "$CFITSIO_DIR" ] && [ -f "$CFITSIO_DIR/fitsio.h" ]; then
    echo "CFITSIO already exists at $CFITSIO_DIR"
    exit 0
fi

# Create directory if it doesn't exist
mkdir -p "$CFITSIO_DIR"

# Download CFITSIO - use workspace directory to avoid sandbox issues
echo "Downloading CFITSIO from GitHub..."
DOWNLOAD_DIR="$PACKAGE_DIR/.cfitsio-download"

# Clean up any previous download attempts
rm -rf "$DOWNLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR"

cd "$DOWNLOAD_DIR"

# Download as zip archive from GitHub (most reliable)
CFITSIO_URL="https://github.com/HEASARC/cfitsio/archive/refs/heads/master.zip"

if command -v curl &> /dev/null; then
    echo "Downloading using curl..."
    # Try with system certs first, fallback to insecure if needed
    curl -L -o cfitsio.zip "$CFITSIO_URL" 2>/dev/null || \
    curl -L --insecure -o cfitsio.zip "$CFITSIO_URL" || {
        echo "Error: Failed to download CFITSIO"
        echo "Please download manually from: https://github.com/HEASARC/cfitsio"
        exit 1
    }
elif command -v wget &> /dev/null; then
    echo "Downloading using wget..."
    wget --no-check-certificate -O cfitsio.zip "$CFITSIO_URL" || {
        echo "Error: Failed to download CFITSIO"
        echo "Please download manually from: https://github.com/HEASARC/cfitsio"
        exit 1
    }
else
    echo "Error: Neither curl nor wget found."
    echo "Please install one of them or download CFITSIO manually."
    exit 1
fi

if [ ! -f cfitsio.zip ]; then
    echo "Error: Failed to download CFITSIO"
    echo "Please download manually from: https://github.com/HEASARC/cfitsio"
    exit 1
fi

# Extract
echo "Extracting CFITSIO..."
if command -v unzip &> /dev/null; then
    unzip -q cfitsio.zip
else
    echo "Error: unzip not found. Please install unzip or extract manually."
    exit 1
fi

# Move to the correct location
if [ -d "cfitsio-master" ]; then
    echo "Moving CFITSIO files to package..."
    mv cfitsio-master/* "$CFITSIO_DIR/"
elif [ -d "cfitsio-develop" ]; then
    echo "Moving CFITSIO files to package..."
    mv cfitsio-develop/* "$CFITSIO_DIR/"
elif [ -d "cfitsio" ]; then
    mv cfitsio/* "$CFITSIO_DIR/"
else
    echo "Error: Unexpected archive structure"
    echo "Contents of download directory:"
    ls -la
    exit 1
fi

# Cleanup
echo "Cleaning up..."
rm -rf "$DOWNLOAD_DIR"

echo "CFITSIO setup complete!"
echo "Location: $CFITSIO_DIR"
echo ""
echo "You can now build the package with: swift build"

