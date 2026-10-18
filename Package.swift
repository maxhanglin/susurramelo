// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Susurramelo",
    platforms: [.macOS("14.2")],
    products: [
        .executable(name: "Susurramelo", targets: ["Susurramelo"]),
    ],
    targets: [
        // Pure logic with no AppKit/AVFoundation dependencies, so it can be unit tested.
        .target(name: "SusurrameloCore"),
        // macOS app shell: audio capture, WebSocket client, hotkey, paste, Keychain, menu bar.
        .executableTarget(
            name: "Susurramelo",
            dependencies: ["SusurrameloCore"]
        ),
        .testTarget(
            name: "SusurrameloCoreTests",
            dependencies: ["SusurrameloCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
