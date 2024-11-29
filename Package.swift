// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Zesty visionOS SDK",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Zesty visionOS SDK",
            targets: ["Zesty visionOS SDK"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Zesty visionOS SDK"),
        .testTarget(
            name: "Zesty visionOS SDKTests",
            dependencies: ["Zesty visionOS SDK"]
        ),
    ]
)
