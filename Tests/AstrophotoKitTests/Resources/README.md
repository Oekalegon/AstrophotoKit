# Test Resources

Place your FITS test files in this directory.

## Usage in Tests

Access test resources using `Bundle.module`:

```swift
let testBundle = Bundle.module
guard let resourcePath = testBundle.path(forResource: "your_file", ofType: "fits") else {
    XCTFail("Test FITS file not found")
    return
}

let fitsFile = try FITSFile(path: resourcePath)
```

Or using `Bundle.module.url(forResource:withExtension:)`:

```swift
guard let resourceURL = Bundle.module.url(forResource: "your_file", withExtension: "fits") else {
    XCTFail("Test FITS file not found")
    return
}

let fitsFile = try FITSFile(path: resourceURL.path)
```

