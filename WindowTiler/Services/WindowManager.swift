import Foundation
import AppKit
import Combine

class WindowManager: ObservableObject {
    @Published var appWindows: [AppWindows] = []

    private let accessibilityService = AccessibilityService.shared
    private let layoutEngine = LayoutEngine()

    // Apps to exclude from window list
    private let excludedApps = [
        "WindowTiler",
        "Finder",  // Often has hidden windows
        "Dock",
        "Window Server",
        "SystemUIServer",
        "Control Center",
        "Notification Center"
    ]

    init() {
        refreshWindows()
    }

    func refreshWindows() {
        let windows = getVisibleWindows()
        appWindows = groupWindowsByApp(windows)
    }

    private func getVisibleWindows() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var windows: [WindowInfo] = []

        for windowDict in windowList {
            guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = windowDict[kCGWindowOwnerName as String] as? String,
                  let ownerPID = windowDict[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = windowDict[kCGWindowLayer as String] as? Int else {
                continue
            }

            // Only include normal windows (layer 0)
            guard layer == 0 else { continue }

            // Skip excluded apps
            guard !excludedApps.contains(ownerName) else { continue }

            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            // Skip very small windows (likely not real windows)
            guard bounds.width > 100 && bounds.height > 100 else { continue }

            let windowName = windowDict[kCGWindowName as String] as? String ?? "Untitled"

            let window = WindowInfo(
                id: windowID,
                name: windowName,
                ownerName: ownerName,
                ownerPID: ownerPID,
                bounds: bounds,
                isOnScreen: true
            )

            windows.append(window)
        }

        return windows
    }

    private func groupWindowsByApp(_ windows: [WindowInfo]) -> [AppWindows] {
        var appDict: [pid_t: AppWindows] = [:]

        for window in windows {
            if var app = appDict[window.ownerPID] {
                app.windows.append(window)
                appDict[window.ownerPID] = app
            } else {
                let runningApp = NSRunningApplication(processIdentifier: window.ownerPID)
                let icon = runningApp?.icon

                appDict[window.ownerPID] = AppWindows(
                    id: window.ownerPID,
                    name: window.ownerName,
                    icon: icon,
                    windows: [window],
                    isSelected: false
                )
            }
        }

        return Array(appDict.values).sorted { $0.name < $1.name }
    }

    func toggleAppSelection(appID: pid_t) {
        if let index = appWindows.firstIndex(where: { $0.id == appID }) {
            appWindows[index].isSelected.toggle()
        }
    }

    func selectAllApps() {
        for index in appWindows.indices {
            appWindows[index].isSelected = true
        }
    }

    func deselectAllApps() {
        for index in appWindows.indices {
            appWindows[index].isSelected = false
        }
    }

    func tileAllWindows() {
        let allWindows = appWindows.flatMap { $0.windows }
        tileWindows(allWindows, position: .full)
    }

    func tileSelectedWindows(position: TilePosition = .full) {
        let selectedWindows = appWindows
            .filter { $0.isSelected }
            .flatMap { $0.windows }

        guard !selectedWindows.isEmpty else { return }
        tileWindows(selectedWindows, position: position)
    }

    private func tileWindows(_ windows: [WindowInfo], position: TilePosition) {
        guard !windows.isEmpty else { return }

        // Check permissions first
        guard accessibilityService.checkPermissions() else {
            accessibilityService.requestPermissions()
            return
        }

        let tileRects = layoutEngine.generateTileRects(windowCount: windows.count, position: position)

        for (index, window) in windows.enumerated() {
            guard index < tileRects.count else { break }

            let screenRect = tileRects[index]
            let windowRect = layoutEngine.convertToWindowCoordinates(screenRect)

            _ = accessibilityService.moveAndResizeWindowByID(
                pid: window.ownerPID,
                targetBounds: window.bounds,
                newRect: windowRect
            )
        }

        // Refresh window list after tiling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshWindows()
        }
    }

    var selectedWindowCount: Int {
        appWindows.filter { $0.isSelected }.reduce(0) { $0 + $1.windowCount }
    }

    var totalWindowCount: Int {
        appWindows.reduce(0) { $0 + $1.windowCount }
    }
}
