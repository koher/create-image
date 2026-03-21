// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CreateImage",
    platforms: [
        .macOS("15.4"),
    ],
    products: [
        .executable(name: "create-image", targets: ["CreateImage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "CreateImageLogics"
        ),
        .target(
            name: "CreateImageLauncher",
            dependencies: ["CreateImageLogics"]
        ),
        .executableTarget(
            name: "CreateImageRunner",
            dependencies: ["CreateImageLogics"]
        ),
        .executableTarget(
            name: "CreateImage",
            dependencies: [
                "CreateImageLauncher",
                "CreateImageLogics",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
