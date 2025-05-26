// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MDEditor",
    platforms: [
        .macOS(.v15),  // Targeting macOS 15 or newer
        .iOS(.v18),    // Targeting iOS 18 or newer
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
                            branch: "main" // Use the latest version from main branch
        ),
        .package(
            url: "https://github.com/jpsim/Yams.git",
            from: "6.0.0" // Use a recent version of Yams
        )
    ],
    targets: [
        .target(
            name: "MDEditor",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Yams", package: "Yams") // Add Yams dependency here
            ],
            resources: [
                .process("Resources/Themes")
            ]
        ),
        .testTarget(
            name: "MDEditorTests",
            dependencies: ["MDEditor"]
        ),
    ]
)

