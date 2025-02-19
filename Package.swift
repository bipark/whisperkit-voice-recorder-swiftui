// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "airecorder",
    platforms: [
        .iOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.12.2")
    ],
    targets: [
        .target(
            name: "airecorder",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "airecorder"
        )
    ]
)
