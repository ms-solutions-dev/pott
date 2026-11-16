// swift-tools-version: 6.2
import PackageDescription

// Colors, fonts (Barlow, OFL) and shared components of Pott. The only place with color values.
// macOS is included so `swift test` answers in seconds on a Mac.
let package = Package(
    name: "PottDesign",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "PottDesign", targets: ["PottDesign"])
    ],
    targets: [
        .target(name: "PottDesign", resources: [.copy("Fonts")]),
        .testTarget(name: "PottDesignTests", dependencies: ["PottDesign"]),
    ]
)
