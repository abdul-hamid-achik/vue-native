// swift-tools-version: 5.9
//
// The iOS core framework. Deliberately ONE product: Xcode auto-generates one
// scheme per SPM product plus a `<Package>-Package` scheme, and with a single
// product the package scheme is named after it and carries the test action —
// which is what `xcodebuild test -scheme VueNativeCore` (CI, `bun run test:ios`,
// AGENTS.md) relies on. Optional components that drag in heavy third-party
// dependencies therefore live in sibling packages, not in extra products here.
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
        //
        // SVGKit — and the CocoaLumberjack `.upToNextMinor(from: "3.9.1")` pin
        // that used to sit beside it — are GONE from this manifest. `<VSVG>` was
        // the only consumer of SVGKit and it moved to the sibling
        // ../VueNativeCoreSVG package, so nothing here references SVGKit any
        // more. That pin's sole purpose was to survive SVGKit's stale platform
        // floors (SVGKit declares iOS 9 while CocoaLumberjack 3.10 requires
        // iOS 15); with SVGKit gone there is nothing left for it to constrain,
        // so it was deleted rather than moved. Consumers of VueNativeCore now
        // resolve FlexLayout + Yoga + VueNativeShared and nothing else.
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
