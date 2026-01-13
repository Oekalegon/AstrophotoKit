# AstrophotoKit

A Swift package for astronomical image processing, including FITS file support and Metal shader integration.

## Features

- **FITS File Support**: Fast FITS file reading/writing using CFITSIO (the official C library)
- **Metal Shaders**: Support for custom Metal shaders for GPU-accelerated image processing
- **Swift API**: Clean, Swifty interface for astronomical data processing

## Installation

Add AstrophotoKit to your project using Swift Package Manager:

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

- macOS 13.0+
- Swift 5.9+
- Xcode 15.0+

## License

See LICENSE file for details.

## Note for Package Maintainers

This package includes CFITSIO source code. If you're setting up the package for development, see `SETUP_CFITSIO.md` for instructions on downloading CFITSIO.

