// swift-tools-version: 6.2
import PackageDescription

// App state of Pott: settings, feature modules and the observable model the screens read.
// No views here, so everything is testable on macOS.
let package = Package(
    name: "PottFeatures",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PottFeatures", targets: ["PottFeatures"])
    ],
    dependencies: [
        .package(path: "../PottCore"),
        .package(path: "../PottStore"),
    ],
    targets: [
        .target(name: "PottFeatures", dependencies: ["PottCore", "PottStore"]),
        .testTarget(name: "PottFeaturesTests", dependencies: ["PottFeatures", "PottCore", "PottStore"]),
    ]
)
