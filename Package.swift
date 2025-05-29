// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MDEditor",
    platforms: [
        .macOS(.v15),  // Targeting macOS 15 or newer
        .iOS(.v18),  // Targeting iOS 18 or newer
    ],
    products: [
        .library(
            name: "MDEditor",
            targets: ["MDEditor"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-markdown.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "MDEditor",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
        ),
        .testTarget(
            name: "MDEditorTests",
            dependencies: ["MDEditor"],
            resources: [
                 .copy("Resources")
             ]
        ),
    ]
)
