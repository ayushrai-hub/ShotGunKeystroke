// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ShotgunKeystroke",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ShotgunKeystroke",
            path: "Sources/ShotgunKeystroke"
        ),
        .testTarget(
            name: "ShotgunKeystrokeTests",
            dependencies: ["ShotgunKeystroke"],
            path: "Tests/ShotgunKeystrokeTests"
        ),
    ]
)
