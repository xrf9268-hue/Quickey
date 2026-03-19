// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Quickey",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Quickey", targets: ["Quickey"])
    ],
    targets: [
        .executableTarget(
            name: "Quickey",
            path: "Sources/Quickey",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "QuickeyTests",
            dependencies: ["Quickey"],
            path: "Tests/QuickeyTests"
        )
    ]
)
