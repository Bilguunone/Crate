// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Crate",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Crate", targets: ["Crate"])
    ],
    targets: [
        .executableTarget(
            name: "Crate",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "CrateTests",
            dependencies: ["Crate"]
        )
    ]
)
