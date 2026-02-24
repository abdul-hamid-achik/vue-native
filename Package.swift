// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VueNativeCore",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "VueNativeCore", targets: ["VueNativeCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/layoutBox/FlexLayout.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "VueNativeCore",
            dependencies: [
                .product(name: "FlexLayout", package: "FlexLayout")
            ],
            path: "native/ios/VueNativeCore/Sources/VueNativeCore",
            resources: [
                .copy("Resources/vue-native-placeholder.js")
            ]
        ),
        .testTarget(
            name: "VueNativeCoreTests",
            dependencies: ["VueNativeCore"],
            path: "native/ios/VueNativeCore/Tests/VueNativeCoreTests"
        )
    ]
)
