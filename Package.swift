// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapgoCapacitorFfmpeg",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapgoCapacitorFfmpeg",
            targets: ["CapacitorFFmpegPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
    ],
    targets: [
        .binaryTarget(
            name: "CapacitorFFmpegNativeCore",
            path: "ios/CapacitorFFmpegNativeCore.xcframework"),
        .target(
            name: "CapacitorFFmpegPlugin",
            dependencies: [
                "CapacitorFFmpegNativeCore",
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/CapacitorFFmpegPlugin",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreServices"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("Security"),
                .linkedFramework("VideoToolbox"),
                .linkedLibrary("c++")
            ]),
        .testTarget(
            name: "CapacitorFFmpegPluginTests",
            dependencies: ["CapacitorFFmpegPlugin"],
            path: "ios/Tests/CapacitorFFmpegPluginTests")
    ]
)
