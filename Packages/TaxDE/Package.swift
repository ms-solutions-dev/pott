// swift-tools-version: 6.2
import PackageDescription

// German pay calculation: wage tax from the BMF program flow chart (generated code) and social
// insurance contributions. Implements PottCore's NetPayCalculator; other countries can add a package
// with their own implementation.
let package = Package(
    name: "TaxDE",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TaxDE", targets: ["TaxDE"])
    ],
    dependencies: [
        .package(path: "../PottCore")
    ],
    targets: [
        .target(name: "TaxDE", dependencies: ["PottCore"], resources: [.copy("HealthInsurers")]),
        .testTarget(name: "TaxDETests", dependencies: ["TaxDE", "PottCore"], resources: [.copy("Fixtures")]),
    ]
)
