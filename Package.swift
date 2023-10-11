// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwipeActions",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "SwipeActions",
            targets: ["SwipeActions"]),
    ],
    dependencies: [
        .package(url: "https://github.com/heestand-xyz/MultiViews", from: "2.1.0"),
    ],
    targets: [
        .target(
            name: "SwipeActions",
            dependencies: ["MultiViews"]),
    ]
)
