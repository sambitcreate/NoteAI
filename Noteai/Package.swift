// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Noteai",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Noteai",
            targets: ["Noteai"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tensorflow/tensorflow.git", .branch("master"))
    ],
    targets: [
        .target(
            name: "Noteai",
            dependencies: [
                .product(name: "TensorFlowLite", package: "tensorflow")
            ]),
        .testTarget(
            name: "NoteaiTests",
            dependencies: ["Noteai"]),
    ]
)
