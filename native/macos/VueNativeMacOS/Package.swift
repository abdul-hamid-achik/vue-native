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
    ],
    targets: [
        .target(
            name: "VueNativeMacOS",
            dependencies: [
                "VueNativeShared",
                .product(name: "SVGKit", package: "SVGKit"),
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
