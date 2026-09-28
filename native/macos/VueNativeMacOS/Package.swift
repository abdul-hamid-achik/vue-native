// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VueNativeMacOS",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "VueNativeMacOS", targets: ["VueNativeMacOS"])
    ],
    dependencies: [
        .package(path: "../../shared/VueNativeShared"),
        // SVG rendering for the VSVG component (iOS + macOS compatible)
        .package(url: "https://github.com/SVGKit/SVGKit.git", from: "3.0.0"),
        // Same constraint as the iOS and root manifests, and for the same
        // reason: this package's Package.resolved is gitignored, so CI and any
        // consumer resolve fresh, and CocoaLumberjack 3.10's macOS 12 floor
        // cannot sit under SVGKit's declared macOS 10.13. See the comment in
        // native/ios/VueNativeCore/Package.swift for the full history.
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMinor(from: "3.9.1")),
    ],
    targets: [
        .target(
            name: "VueNativeMacOS",
            dependencies: [
                "VueNativeShared",
                .product(name: "SVGKit", package: "SVGKit"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            ],
            path: "Sources/VueNativeMacOS",
            resources: [
                .copy("Resources/vue-native-placeholder.js")
            ],
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
        )
    ]
)
