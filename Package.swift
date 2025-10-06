// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TextCastApp",
    platforms: [
        .iOS(.v26),
    ],
    products: [
        .library(
            name: "TextCastApp",
            targets: ["TextCastApp"]
        ),
    ],
    targets: [
        .target(
            name: "TextCastApp"),
        .testTarget(
            name: "TextCastAppTests",
            dependencies: ["TextCastApp"]
        ),
    ]
)
