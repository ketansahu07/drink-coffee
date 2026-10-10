// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "drink-coffee",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "drink", targets: ["drink"])],
    targets: [
        .target(name: "DrinkCore"),
        .executableTarget(name: "drink", dependencies: ["DrinkCore"]),
        .testTarget(name: "DrinkCoreTests", dependencies: ["DrinkCore"])
    ]
)
