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
        .library(name: "VueNativeMacOS", targets: ["VueNativeMacOS"]),
        // Optional `<VSVG>` add-ons. Separate products so a consumer that never
        // renders an SVG can depend on VueNativeCore / VueNativeMacOS alone and
        // never resolve SVGKit — see the dependency comment below.
        .library(name: "VueNativeCoreSVG", targets: ["VueNativeCoreSVG"]),
        .library(name: "VueNativeMacOSSVG", targets: ["VueNativeMacOSSVG"])
    ],
    dependencies: [
        .package(url: "https://github.com/layoutBox/FlexLayout.git", from: "2.0.0"),
        // SVG rendering, used by the two *SVG targets ONLY. `VueNativeCore` and
        // `VueNativeMacOS` do not depend on it, so a consumer that does not add
        // an SVG product never resolves SVGKit, CocoaLumberjack or swift-log.
        .package(url: "https://github.com/SVGKit/SVGKit.git", from: "3.0.0"),
        // SVGKit (2020, declares iOS 9 / macOS 10.13) depends on
        // CocoaLumberjack with an open up-to-next-major range; 3.10 raised its
        // floor to iOS 15 / macOS 12 and breaks the graph. This root manifest is
        // what external SPM consumers resolve and its Package.resolved is
        // gitignored, so every consumer resolution is FRESH — hence the pin.
        //
        // It exists ONLY because of SVGKit, which is why it is attached to the
        // SVG targets below and to nothing else: the core targets no longer
        // depend on SVGKit, so they no longer need (or carry) it. Remove it
        // together with SVGKit itself.
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
                "VueNativeShared"
            ],
            path: "native/ios/VueNativeCore/Sources/VueNativeCore",
            resources: [
                .copy("Resources/vue-native-placeholder.js")
            ]
        ),
        // `<VSVG>` for iOS: the framework's only SVGKit consumer, split out so
        // apps that never render an SVG do not pay for it. Hosts opt in with
        // `VueNativeCoreSVG.register()`. In-repo this is a sibling SPM package
        // (native/ios/VueNativeCoreSVG) because a second *product* in the core
        // package would rename the scheme CI tests; the root manifest flattens
        // both into one graph for external SPM consumers.
        .target(
            name: "VueNativeCoreSVG",
            dependencies: [
                "VueNativeCore",
                .product(name: "FlexLayout", package: "FlexLayout"),
                .product(name: "SVGKit", package: "SVGKit"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack")
            ],
            path: "native/ios/VueNativeCoreSVG/Sources/VueNativeCoreSVG"
        ),
        .target(
            name: "VueNativeMacOS",
            dependencies: [
                "VueNativeShared"
            ],
            path: "native/macos/VueNativeMacOS/Sources/VueNativeMacOS",
            resources: [
                .copy("Resources/vue-native-placeholder.js")
            ]
        ),
        // `<VSVG>` for macOS. Hosts opt in with `VueNativeMacOSSVG.register()`.
        .target(
            name: "VueNativeMacOSSVG",
            dependencies: [
                "VueNativeMacOS",
                .product(name: "SVGKit", package: "SVGKit"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack")
            ],
            path: "native/macos/VueNativeMacOS/Sources/VueNativeMacOSSVG"
        ),
        .testTarget(
            name: "VueNativeCoreTests",
            dependencies: ["VueNativeCore"],
            path: "native/ios/VueNativeCore/Tests/VueNativeCoreTests"
        ),
        .testTarget(
            name: "VueNativeCoreSVGTests",
            dependencies: ["VueNativeCoreSVG"],
            path: "native/ios/VueNativeCoreSVG/Tests/VueNativeCoreSVGTests"
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
        ),
        .testTarget(
            name: "VueNativeMacOSSVGTests",
            dependencies: ["VueNativeMacOSSVG"],
            path: "native/macos/VueNativeMacOS/Tests/VueNativeMacOSSVGTests"
        )
    ]
)
