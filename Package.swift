// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "HexxaXcodeTheme",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "hexxa-xcode-theme",
            targets: ["HexxaXcodeTheme"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HexxaXcodeTheme",
            resources: [
                .copy("Themes")
            ]
        )
    ]
)
