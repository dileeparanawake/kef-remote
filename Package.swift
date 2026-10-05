// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KEFRemote",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KEFRemoteCore", targets: ["KEFRemoteCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0"),
    ],
    targets: [
        .target(
            name: "KEFRemoteCore",
            path: "Sources/KEFRemoteCore"
        ),
        .executableTarget(
            name: "KEFRemote",
            dependencies: [
                "KEFRemoteCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/KEFRemote",
            exclude: ["Info.plist", "KEFRemote.entitlements", "Assets.xcassets"]
        ),
        .executableTarget(
            name: "kef-discover",
            dependencies: ["KEFRemoteCore"],
            path: "Sources/kef-discover"
        ),
        .testTarget(
            name: "KEFRemoteCoreTests",
            dependencies: ["KEFRemoteCore"],
            path: "Tests/KEFRemoteCoreTests"
        ),
    ]
)
