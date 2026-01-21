// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [
        .iOS(.v17),
        .macOS(.v12)
    ],
    products: [
        .library(name: "Data", targets: ["Data"])
    ],
    dependencies: [
        .package(path: "../Domain")
    ],
    targets: [
        .target(
            name: "Data",
            dependencies: [
                .product(name: "Domain", package: "Domain")
            ],
            path: "Sources/Data"
        )
        // Tests があるなら testTarget を追加
    ]
)
