// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "6502MCP",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "Emulator6502",
            targets: ["Emulator6502"]
        ),
        .executable(
            name: "MCPServer",
            targets: ["MCPServer"]
        ),
    ],
    targets: [
        .target(
            name: "Emulator6502",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ]
        ),
        .executableTarget(
            name: "MCPServer",
            dependencies: ["Emulator6502"]
        ),
        .testTarget(
            name: "Emulator6502Tests",
            dependencies: ["Emulator6502"]
        ),
    ],
    swiftLanguageModes: [
        .v5
    ]
)
