// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "dockswap",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DockSwapCore", targets: ["DockSwapCore"]),
        .executable(name: "dockswap", targets: ["dockswap"]),
        .executable(name: "DockSwapMenuBar", targets: ["DockSwapMenuBar"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "DockSwapCore",
            dependencies: [],
            path: "Sources/DockSwapCore",
            sources: ["Models", "DockUtil", "Engine"]
        ),
        .executableTarget(
            name: "dockswap",
            dependencies: [
                "DockSwapCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "DockSwapMenuBar",
            dependencies: ["DockSwapCore"]
        ),
        .testTarget(
            name: "DockSwapCoreTests",
            dependencies: ["DockSwapCore"],
            path: "Tests/DockSwapCoreTests"
        ),
    ]
)
