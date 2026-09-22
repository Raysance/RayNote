// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RayNote",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "RayNote", targets: ["RayNote"])
    ],
    targets: [
        .executableTarget(
            name: "RayNote",
            path: "Sources/RayNote",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "RayNoteTests",
            dependencies: ["RayNote"],
            path: "Tests/RayNoteTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
