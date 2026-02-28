// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KEFRemote",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KEFRemoteCore", targets: ["KEFRemoteCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "KEFRemoteCore",
            path: "Sources/KEFRemoteCore"
        ),
        .testTarget(
            name: "KEFRemoteCoreTests",
            dependencies: ["KEFRemoteCore"],
            path: "Tests/KEFRemoteCoreTests"
        ),
    ]
)
