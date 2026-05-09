// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "quicksave",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "core", targets: ["core"]),
        .executable(name: "app", targets: ["app"]),
        .executable(name: "quicksave", targets: ["cli"])
    ],
    targets: [
        .target(
            name: "core",
            path: "src/core",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "app",
            dependencies: ["core"],
            path: "src/app",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "cli",
            dependencies: ["core"],
            path: "src/cli"
        ),
        .testTarget(
            name: "tests",
            dependencies: ["core"],
            path: "tests",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        )
    ]
)
