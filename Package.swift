// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PivSigner",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PivSigner",
            path: "Sources/PivSigner",
            resources: [.process("Resources")]
        )
    ]
)
