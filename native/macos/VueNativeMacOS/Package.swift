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
    ],
    targets: [
        .target(
            name: "VueNativeMacOS",
            dependencies: ["VueNativeShared"],
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
