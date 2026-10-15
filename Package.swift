// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StepSnap",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "StepSnap", path: "Sources/StepSnap"),
    ],
    swiftLanguageModes: [.v5]
)
