// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Presentation",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        .library(name: "Presentation", targets: ["Presentation"])
    ],
    dependencies: [
        .package(path: "../Domain")
    ],
    targets: [
        .target(
            name: "Presentation",
            dependencies: [
                .product(name: "Domain", package: "Domain")
            ]
        ),
        .testTarget(
            name: "PresentationTests",
            dependencies: ["Presentation"]
        )
    ]
)
