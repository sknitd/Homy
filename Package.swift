// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Homy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Homy", targets: ["Homy"])
    ],
    targets: [
        .executableTarget(
            name: "Homy",
            path: "Sources/Homy"
        )
    ]
)
