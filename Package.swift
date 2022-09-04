// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "SimpleHTTPClient",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "SimpleHTTPClient", targets: ["SimpleHTTPClient"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SimpleHTTPClient",
            dependencies: []
        ),
        .testTarget(
            name: "SimpleHTTPClientTests",
            dependencies: ["SimpleHTTPClient"]
        ),
    ]
)
