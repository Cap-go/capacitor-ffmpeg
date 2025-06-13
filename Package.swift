// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapgoCapacitorFfmpeg",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "CapgoCapacitorFfmpeg",
            targets: ["CapacitorFFmpegPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "CapacitorFFmpegPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/CapacitorFFmpegPlugin"),
        .testTarget(
            name: "CapacitorFFmpegPluginTests",
            dependencies: ["CapacitorFFmpegPlugin"],
            path: "ios/Tests/CapacitorFFmpegPluginTests")
    ]
)
