// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ads-sdk-swift",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ads-sdk-swift",
            targets: ["ads-sdk-swift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.1.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ads-sdk-swift",
            dependencies: [
                .product(name: "Kingfisher", package: "Kingfisher"),
            ]),
        .testTarget(
            name: "ads-sdk-swift-tests",
            dependencies: ["ads-sdk-swift"]
        ),
    ]
)
