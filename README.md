<img src="docs/assets/images/astrophotokit.png" alt="AstrophotoKit logo" width="200" height="200" style="display: block; margin: auto;"/>

# AstrophotoKit

A Swift package for astronomical image processing, including FITS file support and Metal shader integration.

## Documentation

Documentation can be found at: [AstrophotoKit Documentation](https://oekalegon.org/AstrophotoKit/)

## Features

- **FITS File Support**: Fast FITS file reading/writing using CFITSIO (the official C library)
- **Metal Shaders**: Support for custom Metal shaders for GPU-accelerated image processing
- **Swift API**: Clean, Swifty interface for astronomical data processing

## Prerequisites

CFITSIO must be installed on your system before building AstrophotoKit.

### macOS

Install CFITSIO using Homebrew:

```bash
brew install cfitsio
```

### Linux

Install CFITSIO development libraries:

```bash
sudo apt-get install libcfitsio-dev
```

## Installation

Once CFITSIO is installed, add AstrophotoKit to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AstrophotoKit.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["AstrophotoKit"]
)
```

## Usage

### Reading FITS Files

```swift
import AstrophotoKit

do {
    let fitsFile = try FITSFile(path: "/path/to/image.fits")
    let numHDUs = try fitsFile.numberOfHDUs()
    let imageData = try fitsFile.readImageData()
    // Process your image data...
} catch {
    print("Error: \(error)")
}
```

### Metal Shaders

```swift
import AstrophotoKit

let device = AstrophotoKit.makeDefaultDevice()
let library = AstrophotoKit.makeShaderLibrary(device: device)
// Use your Metal shaders...
```

## Requirements

- macOS 14.0+ or Linux
- Swift 5.9+
- Xcode 15.0+ (macOS only)
- CFITSIO library (installed via Homebrew on macOS or apt on Linux)

## License

See LICENSE file for details.
