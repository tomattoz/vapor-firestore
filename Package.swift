// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "vapor-firestore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "VaporFirestore", targets: ["VaporFirestore"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", branch: "main"),
        .package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "8.0.0")
    ],
    targets: [
        .target(name: "VaporFirestore", dependencies: [
            .product(name: "Vapor", package: "vapor"),
            .product(name: "JWT", package: "jwt"),
        ]),
        .testTarget(name: "VaporFirestoreTests", dependencies: [
            .target(name: "VaporFirestore"),
            .product(name: "Nimble", package: "Nimble"),
        ])
    ]
)

