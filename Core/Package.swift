// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReportCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ReportCore",
            targets: ["ReportCore"]
        )
    ],
    targets: [
        .target(
            name: "ReportCore",
            path: "Sources/ReportCore"
        ),
        .testTarget(
            name: "ReportCoreTests",
            dependencies: ["ReportCore"],
            path: "Tests/ReportCoreTests"
        )
    ]
)
