// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Taskmaster",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Taskmaster", targets: ["Taskmaster"])],
    targets: [
        .target(name: "CompanionCore"),
        .executableTarget(
            name: "Taskmaster",
            dependencies: ["CompanionCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "CompanionCoreTests", dependencies: ["CompanionCore"]),
    ]
)
