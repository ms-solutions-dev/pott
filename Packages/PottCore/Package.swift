// swift-tools-version: 6.2
import PackageDescription

// Domain logic of Pott: money, recurrences, budget and household calculations.
// Pure Swift without UI. macOS is included so `swift test` answers in seconds on a Mac.
let package = Package(
    name: "PottCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PottCore", targets: ["PottCore"])
    ],
    targets: [
        .target(name: "PottCore"),
        .testTarget(name: "PottCoreTests", dependencies: ["PottCore"]),
    ]
)
