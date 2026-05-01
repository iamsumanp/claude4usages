// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "claude4usages",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "claude4usages", targets: ["claude4usages"])
    ],
    targets: [
        .target(
            name: "Domain",
            path: "Sources/Domain"
        ),
        .target(
            name: "Infrastructure",
            dependencies: ["Domain"],
            path: "Sources/Infrastructure",
            resources: [
                .process("MenuBar/Resources"),
            ]
        ),
        .executableTarget(
            name: "claude4usages",
            dependencies: ["Domain", "Infrastructure"],
            path: "Sources/App",
            exclude: [
                "Info.plist",
                "entitlements.plist",
                "entitlements.mas.plist",
            ]
        ),
    ]
)
