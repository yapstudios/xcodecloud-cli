// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xcodecloud-cli",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "xcodecloud", targets: ["xcodecloud"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "xcodecloud",
            dependencies: ["XcodeCloudCLI"]
        ),
        .target(
            name: "XcodeCloudCLI",
            dependencies: [
                "XcodeCloudKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "XcodeCloudKit",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ]
        ),
        .testTarget(
            name: "XcodeCloudKitTests",
            dependencies: ["XcodeCloudKit"]
        ),
        .testTarget(
            name: "XcodeCloudCLITests",
            dependencies: [
                "XcodeCloudCLI",
                "XcodeCloudKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
