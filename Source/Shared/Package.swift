// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LibbyWatchShared",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "LibbyWatchShared", targets: ["LibbyWatchShared"]),
        .library(name: "LibbyWatchModels", targets: ["LibbyWatchModels"]),
        .library(name: "LibbyWatchNetworking", targets: ["LibbyWatchNetworking"]),
        .library(name: "LibbyWatchAuth", targets: ["LibbyWatchAuth"]),
        .library(name: "LibbyWatchPlayback", targets: ["LibbyWatchPlayback"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "LibbyWatchModels",
            dependencies: []
        ),
        .target(
            name: "LibbyWatchNetworking",
            dependencies: ["LibbyWatchModels"]
        ),
        .target(
            name: "LibbyWatchAuth",
            dependencies: [
                "LibbyWatchModels",
                "LibbyWatchNetworking",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "JWTKit", package: "jwt-kit"),
            ]
        ),
        .target(
            name: "LibbyWatchPlayback",
            dependencies: ["LibbyWatchModels"]
        ),
        .target(
            name: "LibbyWatchShared",
            dependencies: [
                "LibbyWatchModels",
                "LibbyWatchNetworking",
                "LibbyWatchAuth",
                "LibbyWatchPlayback",
            ]
        ),
        .testTarget(
            name: "LibbyWatchSharedTests",
            dependencies: ["LibbyWatchShared"]
        ),
    ]
)