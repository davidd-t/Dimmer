// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Dimmer",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "DimmerCore"),
        .executableTarget(name: "Dimmer", dependencies: ["DimmerCore"]),
        .testTarget(name: "DimmerCoreTests", dependencies: ["DimmerCore"]),
    ]
)
