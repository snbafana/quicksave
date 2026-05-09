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
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "MacQuicksave",
            dependencies: ["QuicksaveCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "QuicksaveCLI",
            dependencies: ["QuicksaveCore"]
        ),
        .testTarget(
            name: "QuicksaveCoreTests",
            dependencies: ["QuicksaveCore"],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        )
    ]
)
