// swift-tools-version: 5.9

// An App Playground: open this folder in Swift Playgrounds on iPad or Mac and press Run.
// No Xcode required.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Lumen",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Lumen",
            targets: ["AppModule"],
            bundleIdentifier: "com.elpetrichor.lumen",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .camera),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .photoLibrary(purposeString: "Lumen shows, rates and edits the photos in your library."),
                .photoLibraryAdd(purposeString: "Lumen saves edited copies of your photos to your library.")
            ],
            appCategory: .photography
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
