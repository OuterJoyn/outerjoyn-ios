// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OuterJoynSDK",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "OuterJoynSDK", targets: ["OuterJoynSDK"]),
    ],
    targets: [
        .target(
            name: "OuterJoynSDK",
            path: "Sources/OuterJoynSDK"
        ),
    ]
)
