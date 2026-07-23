// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftTexMath",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "SwiftTexMathCore",
            targets: ["SwiftTexMathCore"]
        ),
        .library(
            name: "SwiftTexMath",
            targets: ["SwiftTexMath"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftTexMathCore",
            resources: [
                .copy("Resources/mathFonts.bundle")
            ]
        ),
        .target(
            name: "SwiftTexMath",
            dependencies: ["SwiftTexMathCore"]
        ),
        .testTarget(
            name: "SwiftTexMathCoreTests",
            dependencies: ["SwiftTexMathCore"],
            resources: [
                .copy("Goldens"),
                .copy("Tex2MathCorpus"),
            ]
        ),
        .testTarget(
            name: "SwiftTexMathTests",
            dependencies: ["SwiftTexMath", "SwiftTexMathCore"]
        ),
        .executableTarget(
            name: "SwiftTexMathDemo",
            dependencies: ["SwiftTexMathCore"],
            path: "Examples/Demo"
        ),
    ]
)
