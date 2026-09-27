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
        // SVG rendering for the VSVG component (iOS + macOS compatible)
        .package(url: "https://github.com/SVGKit/SVGKit.git", from: "3.0.0"),
        // SVGKit (last release 2020) declares `.iOS(.v9)` and depends on
        // CocoaLumberjack with an open `.upToNextMajor(from: "3.7.0")` range.
        // CocoaLumberjack 3.10 raised its own floor to iOS 15, so any FRESH
        // resolution fails with "requires minimum platform version 15.0 … but
        // this target supports 12.0 (in target 'SVGKit')". The tracked
        // Package.resolved hid this for in-repo builds, which is why
        // `xcodebuild` here succeeded while every app that consumes this package
        // as a dependency — including `examples/counter` and anything a user
        // scaffolds — failed. Declaring the dependency explicitly constrains the
        // shared resolution graph to the version this package is verified
        // against. Remove this pin only together with SVGKit itself; splitting
        // VSVG into its own product so consumers can avoid SVGKit entirely is
        // the real fix and is tracked separately.
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.9.1")),
        // Shared cross-platform Swift code used by both iOS and macOS
        .package(path: "../../shared/VueNativeShared")
    ],
    targets: [
        .target(
            name: "VueNativeCore",
            dependencies: [
                .product(name: "FlexLayout", package: "FlexLayout"),
                .product(name: "SVGKit", package: "SVGKit"),
                // Referenced only to constrain the shared resolution graph to a
                // CocoaLumberjack that SVGKit's iOS 9 floor can still build
                // against; see the package declaration above.
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
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
