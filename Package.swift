// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "UITestToolkit",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        // Library for Xcode UI test targets - screenshots
        .library(
            name: "ScreenshotKit",
            targets: ["ScreenshotKit"]
        ),
        // Library for Xcode UI test targets - common utilities
        .library(
            name: "UITestKit",
            targets: ["UITestKit"]
        ),
        // CLI tool to extract screenshots from xcresult
        .executable(
            name: "extract-screenshots",
            targets: ["ExtractScreenshots"]
        ),
        // CLI tool to create visual diffs between snapshots (macOS only)
        .executable(
            name: "snapshotsdiff",
            targets: ["SnapshotsDiff"]
        )
    ],
    targets: [
        .target(
            name: "ScreenshotKit",
            dependencies: []
        ),
        .target(
            name: "UITestKit",
            dependencies: []
        ),
        .executableTarget(
            name: "ExtractScreenshots",
            dependencies: []
        ),
        .executableTarget(
            name: "SnapshotsDiff",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("CoreGraphics")
            ]
        )
    ]
)
