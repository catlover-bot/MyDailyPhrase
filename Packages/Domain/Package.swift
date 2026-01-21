// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [
        .iOS(.v17),
        .macOS(.v12)
    ],
    products: [
        // Domain パッケージは Domain だけを提供する
        .library(name: "Domain", targets: ["Domain"]),
    ],
    targets: [
        // Domain のソースが Packages/Domain/Sources 配下に直置きされている前提
        .target(
            name: "Domain",
            path: "Sources"
            // もし過去の名残で Sources/Data が残っていても Domain に混入させない（無ければ無視されます）
        ),

        // もし Tests が存在するなら有効化してください（無い場合はこの testTarget を削除 or コメントアウト）
        // .testTarget(
        //     name: "DomainTests",
        //     dependencies: ["Domain"],
        //     path: "Tests"
        // )
    ]
)
