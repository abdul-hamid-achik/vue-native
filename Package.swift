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
        .package(url: "https://github.com/layoutBox/FlexLayout.git", from: "2.0.0"),
        .package(url: "https://github.com/SVGKit/SVGKit.git", from: "3.0.0"),
        // Same constraint as native/ios/VueNativeCore/Package.swift, and for the
        // same reason: this root manifest is what external SPM consumers resolve,
        // and its Package.resolved is gitignored, so every consumer resolution is
        // FRESH. SVGKit (2020, declares iOS 9 / macOS 10.13) depends on
        // CocoaLumberjack with an open up-to-next-major range; 3.10 raised its
        // floor to iOS 15 / macOS 12 and breaks the graph. Without this pin the
        // consumer-facing build fails on CI even though the nested packages,
        // whose resolved files ARE tracked, build fine locally.
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.9.1"))
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
                .product(name: "SVGKit", package: "SVGKit"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                "VueNativeShared"
            ],
            path: "native/ios/VueNativeCore/Sources/VueNativeCore",
            resources: [
                .copy("Resources/vue-native-placeholder.js")
            ]
        ),
        .target(
            name: "VueNativeMacOS",
            dependencies: [
                .product(name: "SVGKit", package: "SVGKit"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                "VueNativeShared"
            ],
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
