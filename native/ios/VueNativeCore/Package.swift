// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VueNativeCore",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "VueNativeCore", targets: ["VueNativeCore"])
    ],
    dependencies: [
        // Yoga layout engine — layoutBox/FlexLayout v2.x wraps Yoga 3.0.4
        // 2.1k stars, actively maintained (last release Dec 2025), full SPM support
        .package(url: "https://github.com/layoutBox/FlexLayout.git", from: "2.0.0"),
        // Shared cross-platform Swift code used by both iOS and macOS
        .package(path: "../../shared/VueNativeShared")
    ],
    targets: [
        .target(
            name: "VueNativeCore",
            dependencies: [
                .product(name: "FlexLayout", package: "FlexLayout"),
                "VueNativeShared"
            ],
            path: "Sources/VueNativeCore",
            resources: [
                .copy("Resources/vue-native-placeholder.js")
            ]
        ),
        .testTarget(
            name: "VueNativeCoreTests",
            dependencies: ["VueNativeCore"],
            path: "Tests/VueNativeCoreTests"
        )
    ]
)
