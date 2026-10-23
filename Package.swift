// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Taskmaster",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Taskmaster", targets: ["Taskmaster"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0")
    ],
    targets: [
        .target(name: "CompanionCore"),
        .executableTarget(
            name: "Taskmaster",
            dependencies: [
                "CompanionCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            resources: [.process("Resources")],
            // Taskmaster.app keeps Sparkle.framework in Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "CompanionCoreTests", dependencies: ["CompanionCore"]),
        .testTarget(name: "TaskmasterTests", dependencies: ["Taskmaster"]),
    ]
)
