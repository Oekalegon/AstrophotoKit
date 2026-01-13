// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AstrophotoKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AstrophotoKit",
            targets: ["AstrophotoKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // C target wrapping CFITSIO library
        // All .c files in Sources/CAstrophotoKit/cfitsio/ will be automatically compiled by SPM
        .target(
            name: "CAstrophotoKit",
            path: "Sources/CAstrophotoKit",
            exclude: [
                "cfitsio/docs",
                "cfitsio/utilities",
                "cfitsio/cmake",
                "cfitsio/config",
                "cfitsio/m4",
                "cfitsio/licenses",
                "cfitsio/vmsieee.c",  // VMS-specific, not needed on macOS
                "cfitsio/windumpexts.c",  // Windows-specific, not needed on macOS
                "cfitsio/winDumpExts.mak",  // Windows-specific
                "cfitsio/drvrsmem.c",  // Shared memory driver - causes semun conflict on macOS
                "cfitsio/drvrsmem.h",  // Shared memory header - causes semun conflict on macOS
                "cfitsio/iter_a.c",  // Test program with main()
                "cfitsio/iter_b.c",  // Test program with main()
                "cfitsio/iter_c.c",  // Test program with main()
            ],
            publicHeadersPath: "cfitsio",
            cSettings: [
                .headerSearchPath("cfitsio"),
                .define("_REENTRANT"),
                // CFITSIO build defines
                .define("HAVE_UNISTD_H"),
                .define("HAVE_STDLIB_H"),
                .define("HAVE_STRING_H"),
                .define("HAVE_UNION_SEMUN"),  // Prevent semun redefinition on macOS
            ],
            linkerSettings: [
                .linkedLibrary("z"), // zlib for compression support
                .linkedLibrary("m"), // math library
            ]
        ),
        // Swift target that depends on the C library
        .target(
            name: "AstrophotoKit",
            dependencies: ["CAstrophotoKit"],
            resources: [
                .process("Shaders")  // Include Metal shader source files as resources
            ]),
        .testTarget(
            name: "AstrophotoKitTests",
            dependencies: ["AstrophotoKit"],
            resources: [
                .process("Resources")  // Include all FITS test files
            ]),
    ]
)

