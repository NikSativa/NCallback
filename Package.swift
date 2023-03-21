// swift-tools-version:5.6
// swiftformat:disable all
import PackageDescription

let package = Package(
    name: "NCallback",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "NCallback", targets: ["NCallback"]),
        .library(name: "NCallbackTestHelpers", targets: ["NCallbackTestHelpers"])
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "6.1.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "11.2.1")),
        .package(url: "https://github.com/NikSativa/NQueue.git", .upToNextMajor(from: "1.1.16")),
        .package(url: "https://github.com/NikSativa/NSpry.git", .upToNextMajor(from: "1.3.2"))
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
                        .product(name: "NSpry_Nimble", package: "NSpry"),
                        "Nimble",
                        "Quick"
                    ],
                    path: "Tests")
    ]
)
