// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "markdone-viewer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MarkdoneViewerCore",
            targets: ["MarkdoneViewerCore"]
        ),
        .executable(
            name: "MarkdoneViewer",
            targets: ["MarkdoneViewer"]
        )
    ],
    targets: [
        .target(
            name: "MarkdoneViewerCore",
            path: "Sources/MarkdoneViewerCore"
        ),
        .executableTarget(
            name: "MarkdoneViewer",
            dependencies: ["MarkdoneViewerCore"],
            path: "Sources/MarkdoneViewer"
        ),
        .testTarget(
            name: "MarkdoneViewerCoreTests",
            dependencies: ["MarkdoneViewerCore"],
            path: "Tests/MarkdoneViewerCoreTests"
        )
    ]
)
