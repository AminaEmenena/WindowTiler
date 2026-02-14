import Foundation
import AppKit
import Combine

class WindowManager: ObservableObject {
    @Published var appWindows: [AppWindows] = []
    @Published var canUndo: Bool = false
    @Published var isInFocusMode: Bool = false

    private let accessibilityService = AccessibilityService.shared
    private let layoutEngine = LayoutEngine()

    // Store previous window positions for undo
    private var previousWindowPositions: [CGWindowID: CGRect] = [:]
    private var previousWindowPIDs: [CGWindowID: pid_t] = [:]

    // Store window positions for focus mode
    private var focusModeStoredPositions: [CGWindowID: CGRect] = [:]

    // Apps to exclude from window list
    private let excludedApps = [
        "WindowTiler",
        "Finder",
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

            guard layer == 0 else { continue }
            guard !excludedApps.contains(ownerName) else { continue }

            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

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

    // MARK: - Selection

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

    // MARK: - Quick Groups Support

    func getSelectedBundleIdentifiers() -> [String] {
        return appWindows
            .filter { $0.isSelected }
            .compactMap { app -> String? in
                guard let runningApp = NSRunningApplication(processIdentifier: app.id) else {
                    return nil
                }
                return runningApp.bundleIdentifier
            }
    }

    func selectAppsByBundleIdentifiers(_ bundleIdentifiers: [String]) {
        deselectAllApps()

        for index in appWindows.indices {
            if let runningApp = NSRunningApplication(processIdentifier: appWindows[index].id),
               let bundleId = runningApp.bundleIdentifier,
               bundleIdentifiers.contains(bundleId) {
                appWindows[index].isSelected = true
            }
        }
    }

    // MARK: - Tiling

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

    func tileWindowsAcrossAllDisplays() {
        let selectedWindows = appWindows
            .filter { $0.isSelected }
            .flatMap { $0.windows }

        guard !selectedWindows.isEmpty else { return }

        guard accessibilityService.checkPermissions() else {
            accessibilityService.requestPermissions()
            return
        }

        // Store for undo
        storeWindowPositions(selectedWindows)

        let tileRectsWithScreens = layoutEngine.generateTileRectsAcrossDisplays(windowCount: selectedWindows.count)

        for (index, window) in selectedWindows.enumerated() {
            guard index < tileRectsWithScreens.count else { break }

            let (screenRect, screen) = tileRectsWithScreens[index]
            let windowRect = layoutEngine.convertToWindowCoordinates(screenRect, relativeTo: screen)

            _ = accessibilityService.moveAndResizeWindowByID(
                pid: window.ownerPID,
                targetBounds: window.bounds,
                newRect: windowRect
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshWindows()
        }
    }

    private func tileWindows(_ windows: [WindowInfo], position: TilePosition) {
        guard !windows.isEmpty else { return }

        guard accessibilityService.checkPermissions() else {
            accessibilityService.requestPermissions()
            return
        }

        if position == .allDisplays {
            tileWindowsAcrossAllDisplays()
            return
        }

        // Store for undo
        storeWindowPositions(windows)

        // Group windows by screen for multi-monitor support
        var windowsByScreen: [NSScreen: [WindowInfo]] = [:]

        for window in windows {
            let screen = layoutEngine.screenForWindowBounds(window.bounds)
            if windowsByScreen[screen] == nil {
                windowsByScreen[screen] = []
            }
            windowsByScreen[screen]?.append(window)
        }

        // Tile windows on each screen independently
        for (screen, screenWindows) in windowsByScreen {
            let tileRects = layoutEngine.generateTileRects(
                windowCount: screenWindows.count,
                position: position,
                screen: screen
            )

            for (index, window) in screenWindows.enumerated() {
                guard index < tileRects.count else { break }

                let screenRect = tileRects[index]
                let windowRect = layoutEngine.convertToWindowCoordinates(screenRect, relativeTo: screen)

                _ = accessibilityService.moveAndResizeWindowByID(
                    pid: window.ownerPID,
                    targetBounds: window.bounds,
                    newRect: windowRect
                )
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshWindows()
        }
    }

    // MARK: - Undo

    private func storeWindowPositions(_ windows: [WindowInfo]) {
        previousWindowPositions.removeAll()
        previousWindowPIDs.removeAll()

        for window in windows {
            previousWindowPositions[window.id] = window.bounds
            previousWindowPIDs[window.id] = window.ownerPID
        }

        canUndo = !previousWindowPositions.isEmpty
    }

    func undoLastTile() {
        guard canUndo else { return }

        guard accessibilityService.checkPermissions() else {
            accessibilityService.requestPermissions()
            return
        }

        for (windowID, previousBounds) in previousWindowPositions {
            guard let pid = previousWindowPIDs[windowID] else { continue }

            if let currentBounds = getCurrentWindowBounds(windowID: windowID) {
                let windowRect = layoutEngine.convertToWindowCoordinates(previousBounds)
                _ = accessibilityService.moveAndResizeWindowByID(
                    pid: pid,
                    targetBounds: currentBounds,
                    newRect: windowRect
                )
            }
        }

        previousWindowPositions.removeAll()
        previousWindowPIDs.removeAll()
        canUndo = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshWindows()
        }
    }

    private func getCurrentWindowBounds(windowID: CGWindowID) -> CGRect? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for windowDict in windowList {
            guard let id = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  id == windowID,
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat] else {
                continue
            }

            return CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
        }

        return nil
    }

    // MARK: - Focus Mode

    var canEnterFocusMode: Bool {
        selectedWindowCount == 1
    }

    func enterFocusMode() {
        let selectedWindows = appWindows
            .filter { $0.isSelected }
            .flatMap { $0.windows }

        guard selectedWindows.count == 1, let focusWindow = selectedWindows.first else {
            return
        }

        guard accessibilityService.checkPermissions() else {
            accessibilityService.requestPermissions()
            return
        }

        // Store ALL visible window positions
        let allWindows = appWindows.flatMap { $0.windows }
        focusModeStoredPositions = [:]
        for window in allWindows {
            focusModeStoredPositions[window.id] = window.bounds
        }

        // Maximize the focus window
        let usableArea = layoutEngine.getUsableScreenArea()
        let windowRect = layoutEngine.convertToWindowCoordinates(usableArea)

        _ = accessibilityService.moveAndResizeWindowByID(
            pid: focusWindow.ownerPID,
            targetBounds: focusWindow.bounds,
            newRect: windowRect
        )

        isInFocusMode = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshWindows()
        }
    }

    func exitFocusMode() {
        guard isInFocusMode else { return }

        guard accessibilityService.checkPermissions() else {
            accessibilityService.requestPermissions()
            return
        }

        refreshWindows()

        let allWindows = appWindows.flatMap { $0.windows }
        for window in allWindows {
            if let storedBounds = focusModeStoredPositions[window.id] {
                _ = accessibilityService.moveAndResizeWindowByID(
                    pid: window.ownerPID,
                    targetBounds: window.bounds,
                    newRect: storedBounds
                )
            }
        }

        focusModeStoredPositions = [:]
        isInFocusMode = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshWindows()
        }
    }

    // MARK: - Computed Properties

    var selectedWindowCount: Int {
        appWindows.filter { $0.isSelected }.reduce(0) { $0 + $1.windowCount }
    }

    var totalWindowCount: Int {
        appWindows.reduce(0) { $0 + $1.windowCount }
    }
}
