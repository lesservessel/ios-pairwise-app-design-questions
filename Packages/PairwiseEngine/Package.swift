// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PairwiseEngine",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "PairwiseEngine", targets: ["PairwiseEngine"])
    ],
    targets: [
        .target(name: "PairwiseEngine"),
        .testTarget(name: "PairwiseEngineTests", dependencies: ["PairwiseEngine"])
    ]
)
