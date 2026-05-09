// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Quicksave",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "QuicksaveCore", targets: ["QuicksaveCore"]),
        .executable(name: "MacQuicksave", targets: ["MacQuicksave"]),
        .executable(name: "quicksave", targets: ["QuicksaveCLI"])
    ],
    targets: [
        .target(
            name: "QuicksaveCore",
            path: "src/core",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "MacQuicksave",
            dependencies: ["QuicksaveCore"],
            path: "src/app",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "QuicksaveCLI",
            dependencies: ["QuicksaveCore"],
            path: "src/cli"
        ),
        .testTarget(
            name: "QuicksaveCoreTests",
            dependencies: ["QuicksaveCore"],
            path: "tests",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        )
    ]
)
