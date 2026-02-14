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
                "Models/AppGroup.swift",
                "Models/SavedLayout.swift",
                "Services/AccessibilityService.swift",
                "Services/LayoutEngine.swift",
                "Services/WindowManager.swift",
                "Services/SettingsService.swift",
                "Services/LaunchAtLoginService.swift",
                "Services/GroupStorage.swift",
                "Services/LayoutStorage.swift",
                "Views/MenuBarView.swift"
            ]
        )
    ]
)
