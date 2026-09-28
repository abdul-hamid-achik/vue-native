// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VueNativeMacOS",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "VueNativeMacOS", targets: ["VueNativeMacOS"]),
        // Optional add-on: `<VSVG>`. Kept as a separate product so an app that
        // never renders an SVG does not resolve SVGKit at all — see the
        // dependency comment below.
        .library(name: "VueNativeMacOSSVG", targets: ["VueNativeMacOSSVG"])
    ],
    dependencies: [
        .package(path: "../../shared/VueNativeShared"),
        // SVG rendering for the VSVG component (iOS + macOS compatible).
        // Used by the VueNativeMacOSSVG target ONLY — `VueNativeMacOS` does not
        // depend on it, so a consumer that does not add the VueNativeMacOSSVG
        // product never resolves SVGKit, CocoaLumberjack or swift-log.
        .package(url: "https://github.com/SVGKit/SVGKit.git", from: "3.0.0"),
        // This package's Package.resolved is gitignored, so CI and any consumer
        // resolve fresh, and CocoaLumberjack 3.10's macOS 12 floor cannot sit
        // under SVGKit's declared macOS 10.13. The pin exists ONLY because of
        // SVGKit, which is why it is declared on the VueNativeMacOSSVG target
        // below and nowhere else — `VueNativeMacOS` no longer depends on SVGKit,
        // so it no longer needs (or carries) the pin. See the comment in
        // native/ios/VueNativeCore/Package.swift for the full history.
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.9.1")),
    ],
    targets: [
        .target(
            name: "VueNativeMacOS",
            dependencies: [
                "VueNativeShared",
            ],
            path: "Sources/VueNativeMacOS",
            resources: [
                .copy("Resources/vue-native-placeholder.js")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // `<VSVG>` and everything it alone needs. Depends on SVGKit and on the
        // core target (for NativeComponentFactory, FlippedView/LayoutNode, the
        // style router and the optional-component registration seam). Hosts opt
        // in with `VueNativeMacOSSVG.register()`; see Sources/VueNativeMacOSSVG.
        .target(
            name: "VueNativeMacOSSVG",
            dependencies: [
                "VueNativeMacOS",
                .product(name: "SVGKit", package: "SVGKit"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            ],
            path: "Sources/VueNativeMacOSSVG",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "VueNativeMacOSTests",
            dependencies: ["VueNativeMacOS"],
            path: "Tests/VueNativeMacOSTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // Separate test target so the core test bundle stays free of SVGKit: it
        // is what proves `<VSVG>` is absent from a core-only registration.
        .testTarget(
            name: "VueNativeMacOSSVGTests",
            dependencies: ["VueNativeMacOSSVG"],
            path: "Tests/VueNativeMacOSSVGTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
