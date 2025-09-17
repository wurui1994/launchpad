// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LaunchPad",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LaunchPad", targets: ["LaunchPad"])
    ],
    targets: [
        .executableTarget(
            name: "LaunchPad",
            path: "Sources/LaunchPad",
            publicHeadersPath: nil,
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)