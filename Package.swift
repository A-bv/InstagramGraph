// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InstagramGraph",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "InstagramGraph", targets: ["InstagramGraph"]),
    ],
    targets: [
        .target(name: "InstagramGraph"),
        .testTarget(name: "InstagramGraphTests", dependencies: ["InstagramGraph"]),
    ]
)
