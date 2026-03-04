// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CodingPlanStatus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CodingPlanStatusCore", targets: ["CodingPlanStatusCore"]),
        .library(name: "CodingPlanStatusProviders", targets: ["CodingPlanStatusProviders"]),
        .library(name: "CodingPlanStatusStorage", targets: ["CodingPlanStatusStorage"]),
        .executable(name: "CodingPlanStatusApp", targets: ["CodingPlanStatusApp"])
    ],
    targets: [
        .target(name: "CodingPlanStatusCore"),
        .target(
            name: "CodingPlanStatusProviders",
            dependencies: ["CodingPlanStatusCore"]
        ),
        .target(
            name: "CodingPlanStatusStorage",
            dependencies: ["CodingPlanStatusCore"]
        ),
        .executableTarget(
            name: "CodingPlanStatusApp",
            dependencies: [
                "CodingPlanStatusCore",
                "CodingPlanStatusProviders",
                "CodingPlanStatusStorage"
            ]
        ),
        .testTarget(
            name: "CodingPlanStatusCoreTests",
            dependencies: ["CodingPlanStatusCore"]
        ),
        .testTarget(
            name: "CodingPlanStatusProvidersTests",
            dependencies: ["CodingPlanStatusProviders", "CodingPlanStatusCore"]
        )
    ]
)
