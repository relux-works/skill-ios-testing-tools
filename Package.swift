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
        .library(
            name: "IOSE2EPeerClient",
            targets: ["IOSE2EPeerClient"]
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
        ),
        // CLI tool to build an iOS app for connected physical devices
        .executable(
            name: "ios-device-build",
            targets: ["IOSDeviceBuild"]
        ),
        // CLI tool to coordinate multi-peer iOS UI E2E sessions
        .executable(
            name: "ios-e2e-runner",
            targets: ["IOSE2ERunnerCLI"]
        ),
        // Sample fake peer used by the generalized E2E coordinator proof
        .executable(
            name: "e2e-fake-peer",
            targets: ["IOSE2EFakePeer"]
        ),
        // Sample fake peer that uses the UI-test peer-listener transport
        .executable(
            name: "e2e-listener-fake-peer",
            targets: ["IOSE2EListenerFakePeer"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3")
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
        .target(
            name: "IOSE2EPeerClient",
            dependencies: ["IOSE2ECoordinatorCore"]
        ),
        .target(
            name: "IOSE2ECoordinatorCore",
            dependencies: []
        ),
        .target(
            name: "IOSE2ECoordinatorTransport",
            dependencies: [
                "IOSE2ECoordinatorCore",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio")
            ]
        ),
        .target(
            name: "IOSE2ERunner",
            dependencies: [
                "IOSE2ECoordinatorCore",
                "IOSE2ECoordinatorTransport",
                .product(name: "Yams", package: "Yams")
            ]
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
        ),
        .executableTarget(
            name: "IOSDeviceBuild",
            dependencies: []
        ),
        .executableTarget(
            name: "IOSE2ERunnerCLI",
            dependencies: ["IOSE2ERunner"]
        ),
        .executableTarget(
            name: "IOSE2EFakePeer",
            dependencies: ["IOSE2ECoordinatorCore"]
        ),
        .executableTarget(
            name: "IOSE2EListenerFakePeer",
            dependencies: ["IOSE2EPeerClient"]
        ),
        .testTarget(
            name: "IOSE2ECoordinatorCoreTests",
            dependencies: ["IOSE2ECoordinatorCore"]
        ),
        .testTarget(
            name: "IOSE2ECoordinatorTransportTests",
            dependencies: ["IOSE2ECoordinatorTransport"]
        ),
        .testTarget(
            name: "UITestKitE2ETests",
            dependencies: ["IOSE2EPeerClient"]
        ),
        .testTarget(
            name: "IOSE2ERunnerTests",
            dependencies: ["IOSE2ERunner"]
        )
    ]
)
