// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "enums",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "enums",
            targets: ["enums"]
        ),
    ],
    dependencies: [
        // Add external dependencies here, e.g.:
        // .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "enums",
            dependencies: [
                // List target dependencies here (if any).
            ],
            path: "Sources/enums"
        ),
        // Enable this section when you add tests:
        // .testTarget(
        //     name: "enumsTests",
        //     dependencies: ["enums"],
        //     path: "Tests/enumsTests"
        // )
    ]
)
