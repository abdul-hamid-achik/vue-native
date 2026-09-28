// swift-tools-version: 5.9
//
// Optional `<VSVG>` add-on for VueNativeCore (iOS).
//
// WHY A SEPARATE PACKAGE, not a second product in ../VueNativeCore:
// `<VSVG>` is the framework's only SVGKit consumer, and SVGKit (last release
// 2020, Objective-C-heavy) drags in CocoaLumberjack plus a version pin that
// every consumer of it would otherwise inherit. Splitting it out means an app
// that never renders an SVG never resolves SVGKit at all.
//
// It cannot be a second product of the core package because Xcode auto-generates
// one scheme per SPM *product* plus a `<Package>-Package` scheme. With a single
// product the package scheme is named after it (`VueNativeCore`) and carries the
// test action; with two products `VueNativeCore` becomes a product scheme with an
// empty TestAction and the tests move to `VueNativeCore-Package`, which breaks
// `xcodebuild test -scheme VueNativeCore` in CI, `bun run test:ios` and AGENTS.md.
// A sibling package keeps the core package's scheme — and its test gate — exactly
// as they were.
import PackageDescription

let package = Package(
    name: "VueNativeCoreSVG",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "VueNativeCoreSVG", targets: ["VueNativeCoreSVG"])
    ],
    dependencies: [
        // The core framework: NativeComponentFactory, VueNativeComponentSupport
        // (style router + hex colors) and the optional-component registration
        // seam this product bootstraps through.
        .package(path: "../VueNativeCore"),
        // Yoga layout engine — the SVG view is a FlexLayout participant.
        .package(url: "https://github.com/layoutBox/FlexLayout.git", from: "2.0.0"),
        // SVG rendering (iOS + macOS compatible).
        .package(url: "https://github.com/SVGKit/SVGKit.git", from: "3.0.0"),
        // SVGKit (last release 2020) declares `.iOS(.v9)` and depends on
        // CocoaLumberjack with an open `.upToNextMajor(from: "3.7.0")` range.
        // CocoaLumberjack 3.10 raised its own floor to iOS 15, so any FRESH
        // resolution fails with "requires minimum platform version 15.0 … but
        // this target supports 12.0 (in target 'SVGKit')". Declaring the
        // dependency explicitly constrains the shared resolution graph to the
        // version this package is verified against.
        //
        // This pin exists ONLY because of SVGKit and lives ONLY here. The core
        // manifest no longer references SVGKit, so it no longer carries a pin —
        // which is the point of the split. Remove it together with SVGKit.
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.9.1"))
    ],
    targets: [
        .target(
            name: "VueNativeCoreSVG",
            dependencies: [
                .product(name: "VueNativeCore", package: "VueNativeCore"),
                .product(name: "FlexLayout", package: "FlexLayout"),
                .product(name: "SVGKit", package: "SVGKit"),
                // Referenced only to constrain the shared resolution graph to a
                // CocoaLumberjack that SVGKit's iOS 9 floor can still build
                // against; see the package declaration above.
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack")
            ],
            path: "Sources/VueNativeCoreSVG"
        ),
        .testTarget(
            name: "VueNativeCoreSVGTests",
            dependencies: ["VueNativeCoreSVG"],
            path: "Tests/VueNativeCoreSVGTests"
        )
    ]
)
