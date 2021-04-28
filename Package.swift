// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-docker",
    platforms: [.macOS(.v10_13)],
    products: [
        .executable(name: "swift-docker", targets: ["swift-docker"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-mustache.git", from: "0.5.0"),
        .package(name: "SwiftPM", url: "https://github.com/apple/swift-package-manager.git", .branch("swift-5.4-RELEASE")),
    ],
    targets: [
        .target(
            name: "swift-docker",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "HummingbirdMustache", package: "hummingbird-mustache"),
                .product(name: "SwiftPM-auto", package: "SwiftPM"),
            ],
            resources: [.process("templates")]
        ),
        .testTarget(
            name: "swift-dockerTests",
            dependencies: ["swift-docker"]
        ),
    ]
)
