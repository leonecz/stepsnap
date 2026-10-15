// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StepSnap",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "StepSnapCore", path: "Sources/StepSnapCore"),
        .executableTarget(name: "StepSnap", dependencies: ["StepSnapCore"], path: "Sources/StepSnap"),
        .testTarget(name: "StepSnapCoreTests", dependencies: ["StepSnapCore"], path: "Tests/StepSnapCoreTests"),
    ],
    swiftLanguageModes: [.v5]
)
