// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IronClawRemote",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .iOSApplication(
            name: "IronClaw Remote",
            targets: ["IronClawRemote"],
            bundleIdentifier: "ai.near.ironclaw.remote",
            teamIdentifier: "",
            displayVersion: "1.0.0",
            bundleVersion: "1",
            iconAssetName: "AppIcon",
            accentColorAssetName: "AccentColor",
            supportedDeviceFamilies: [
                .phone,
                .pad
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeLeft,
                .landscapeRight,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "IronClawRemote",
            path: "IronClawRemote",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        )
    ]
)
