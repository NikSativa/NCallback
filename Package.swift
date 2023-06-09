// swift-tools-version:5.8
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "NCallback",
    platforms: [
        .iOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(name: "NCallback", targets: ["NCallback"]),
        .library(name: "NCallbackTestHelpers", targets: ["NCallbackTestHelpers"])
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "7.0.1")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "12.0.1")),
        .package(url: "https://github.com/NikSativa/NQueue.git", .upToNextMajor(from: "1.2.2")),
        .package(url: "https://github.com/NikSativa/NSpry.git", .upToNextMajor(from: "2.1.0")),
        .package(url: "https://github.com/NikSativa/NSpryNimble.git", .upToNextMajor(from: "2.0.0"))
    ],
    targets: [
        .target(name: "NCallback",
                dependencies: [
                    "NQueue"
                ],
                path: "Source"),
        .target(name: "NCallbackTestHelpers",
                dependencies: [
                    "NCallback",
                    "NSpry"
                ],
                path: "TestHelpers"),
        .testTarget(name: "NCallbackTests",
                    dependencies: [
                        "NCallback",
                        "NCallbackTestHelpers",
                        "NQueue",
                        .product(name: "NQueueTestHelpers", package: "NQueue"),
                        "NSpry",
                        "NSpryNimble",
                        "Nimble",
                        "Quick"
                    ],
                    path: "Tests")
    ]
)
