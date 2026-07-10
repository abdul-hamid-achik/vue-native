// swift-tools-version: 5.9
//
// Root Swift package — this is the package external SPM consumers resolve
// when adding `https://github.com/abdul-hamid-achik/vue-native` as a dependency.
//
// In-repo Swift development continues to use the nested Package.swift files
// under native/ios/VueNativeCore, native/shared/VueNativeShared, and
// native/macos/VueNativeMacOS.
import PackageDescription

let package = Package(
    name: "VueNativeCore",
    platforms: [
        .iOS(.v16),
        .macOS("15.0")
    ],
    products: [
        .library(name: "VueNativeCore", targets: ["VueNativeCore"]),
        .library(name: "VueNativeShared", targets: ["VueNativeShared"]),
        .library(name: "VueNativeMacOS", targets: ["VueNativeMacOS"])
    ],
    dependencies: [
        .package(url: "https://github.com/layoutBox/FlexLayout.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "VueNativeShared",
            path: "native/shared/VueNativeShared/Sources/VueNativeShared"
        ),
        .target(
            name: "VueNativeCore",
            dependencies: [
                .product(name: "FlexLayout", package: "FlexLayout"),
                "VueNativeShared"
            ],
            path: "native/ios/VueNativeCore/Sources/VueNativeCore",
            resources: [
                .copy("Resources/vue-native-placeholder.js")
            ]
        ),
        .target(
            name: "VueNativeMacOS",
            dependencies: ["VueNativeShared"],
            path: "native/macos/VueNativeMacOS/Sources/VueNativeMacOS",
            resources: [
                .copy("Resources/vue-native-placeholder.js")
            ]
        ),
        .testTarget(
            name: "VueNativeCoreTests",
            dependencies: ["VueNativeCore"],
            path: "native/ios/VueNativeCore/Tests/VueNativeCoreTests"
        ),
        .testTarget(
            name: "VueNativeSharedTests",
            dependencies: ["VueNativeShared"],
            path: "native/shared/VueNativeShared/Tests/VueNativeSharedTests"
        ),
        .testTarget(
            name: "VueNativeMacOSTests",
            dependencies: ["VueNativeMacOS"],
            path: "native/macos/VueNativeMacOS/Tests/VueNativeMacOSTests"
        )
    ]
)
