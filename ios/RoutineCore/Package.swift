// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RoutineCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RoutineCore", targets: ["RoutineCore"]),
    ],
    targets: [
        .target(name: "RoutineCore"),
        .testTarget(name: "RoutineCoreTests", dependencies: ["RoutineCore"]),
    ]
)
