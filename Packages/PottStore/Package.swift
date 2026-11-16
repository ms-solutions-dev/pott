// swift-tools-version: 6.2
import PackageDescription

// Persistence of Pott: Core Data with a private and a shared CloudKit store (see docs/ADR-001-sync.md).
// The rest of the app only sees PottCore value types through `Repository`.
let package = Package(
    name: "PottStore",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PottStore", targets: ["PottStore"])
    ],
    dependencies: [
        .package(path: "../PottCore")
    ],
    targets: [
        .target(name: "PottStore", dependencies: ["PottCore"]),
        .testTarget(name: "PottStoreTests", dependencies: ["PottStore", "PottCore"]),
    ]
)
