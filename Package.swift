// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacVital",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacVitalHelper",
            dependencies: ["MacVitalShared"],
            path: "MacVitalHelper"
        ),
        .target(
            name: "MacVitalShared",
            path: "Shared"
        ),
        .testTarget(
            name: "MacVitalTests",
            dependencies: ["MacVitalShared"],
            path: "Tests"
        )
    ]
)
