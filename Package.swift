// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WindowTiler",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "WindowTiler",
            path: "WindowTiler",
            sources: [
                "WindowTilerApp.swift",
                "Models/WindowInfo.swift",
                "Services/AccessibilityService.swift",
                "Services/LayoutEngine.swift",
                "Services/WindowManager.swift",
                "Views/MenuBarView.swift"
            ]
        )
    ]
)
