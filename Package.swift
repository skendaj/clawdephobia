// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Claudephobia",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Claudephobia",
            path: "Sources",
            resources: [
                .copy("Resources/icon.png")
            ]
        )
    ]
)
