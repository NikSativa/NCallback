// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NCallback",
    platforms: [
        .iOS(.v10)
    ],
    products: [
        .library(name: "NCallback", targets: ["NCallback"]),
        .library(name: "NCallbackTestHelpers", targets: ["NCallbackTestHelpers"])
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "3.1.2")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "9.0.0")),
        .package(url: "git@github.com:NikSativa/NQueue.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "git@github.com:NikSativa/NSpry.git", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(name: "NCallback",
                dependencies: ["NQueue"],
                path: "Source"),
        .target(name: "NCallbackTestHelpers",
                dependencies: ["NCallback",
                               "NQueue",
                               .product(name: "NQueueTestHelpers", package: "NQueue"),
                               "NSpry"],
                path: "TestHelpers"),
        .testTarget(name: "NCallbackTests",
                    dependencies: ["NCallback",
                                   "NCallbackTestHelpers",
                                   "NQueue",
                                   .product(name: "NQueueTestHelpers", package: "NQueue"),
                                   "NSpry",
                                   "Nimble",
                                   "Quick"],
                    path: "Tests/Specs")
    ],
    swiftLanguageVersions: [.v5]
)
