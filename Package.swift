// swift-tools-version:5.2

import PackageDescription

// swiftformat:disable all
let package = Package(
    name: "NCallback",
    platforms: [.iOS(.v12), .macOS(.v10_12)],
    products: [
        .library(name: "NCallback", targets: ["NCallback"]),
        .library(name: "NCallbackTestHelpers", targets: ["NCallbackTestHelpers"])
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "9.2.1")),
        .package(url: "https://github.com/NikSativa/NQueue.git", .upToNextMajor(from: "1.1.8")),
        .package(url: "https://github.com/NikSativa/NSpry.git", .upToNextMajor(from: "1.1.4"))
    ],
    targets: [
        .target(name: "NCallback",
                dependencies: ["NQueue"],
                path: "Source"),
        .target(name: "NCallbackTestHelpers",
                dependencies: ["NCallback",
                               "NSpry"],
                path: "TestHelpers"),
        .testTarget(name: "NCallbackTests",
                    dependencies: ["NCallback",
                                   "NCallbackTestHelpers",
                                   "NQueue",
                                   .product(name: "NQueueTestHelpers", package: "NQueue"),
                                   "NSpry",
                                   .product(name: "NSpry_Nimble", package: "NSpry"),
                                   "Nimble",
                                   "Quick"],
                    path: "Tests")
    ],
    swiftLanguageVersions: [.v5]
)
