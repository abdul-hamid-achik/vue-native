// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VueNativeShared",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "VueNativeShared", targets: ["VueNativeShared"])
    ],
    targets: [
        .target(name: "VueNativeShared", path: "Sources/VueNativeShared"),
        .testTarget(name: "VueNativeSharedTests", dependencies: ["VueNativeShared"], path: "Tests/VueNativeSharedTests")
    ]
)
