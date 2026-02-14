import Foundation
import AppKit

class LayoutStorage: ObservableObject {
    static let shared = LayoutStorage()

    @Published var savedLayouts: [SavedLayout] = []

    private let fileManager = FileManager.default
    private var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("WindowTiler", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appFolder.path) {
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }

        return appFolder.appendingPathComponent("saved_layouts.json")
    }

    private init() {
        loadLayouts()
    }

    // MARK: - Public Methods

    func saveLayout(name: String, windows: [WindowInfo]) -> Bool {
        var positions: [WindowPosition] = []

        for window in windows {
            // Get bundle ID from running application
            let runningApp = NSRunningApplication(processIdentifier: window.ownerPID)
            let bundleID = runningApp?.bundleIdentifier ?? "unknown.\(window.ownerName)"

            let position = WindowPosition(
                bundleID: bundleID,
                appName: window.ownerName,
                frame: window.bounds
            )
            positions.append(position)
        }

        let layout = SavedLayout(name: name, windowPositions: positions)
        savedLayouts.insert(layout, at: 0)

        return persistLayouts()
    }

    func deleteLayout(id: UUID) {
        savedLayouts.removeAll { $0.id == id }
        _ = persistLayouts()
    }

    func deleteLayout(at offsets: IndexSet) {
        savedLayouts.remove(atOffsets: offsets)
        _ = persistLayouts()
    }

    func restoreLayout(_ layout: SavedLayout, using accessibilityService: AccessibilityService) {
        // Group window positions by bundle ID
        let positionsByApp = Dictionary(grouping: layout.windowPositions) { $0.bundleID }

        for (bundleID, positions) in positionsByApp {
            // Find running application with this bundle ID
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)

            guard let app = runningApps.first else {
                // App not running, try to launch it
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
                }
                continue
            }

            // Restore each window position for this app
            for position in positions {
                _ = accessibilityService.moveAndResizeWindowByID(
                    pid: app.processIdentifier,
                    targetBounds: position.frame,
                    newRect: position.frame
                )
            }
        }
    }

    // MARK: - Private Methods

    private func loadLayouts() {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            savedLayouts = []
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            savedLayouts = try decoder.decode([SavedLayout].self, from: data)
        } catch {
            print("Failed to load layouts: \(error)")
            savedLayouts = []
        }
    }

    private func persistLayouts() -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(savedLayouts)
            try data.write(to: storageURL, options: .atomic)
            return true
        } catch {
            print("Failed to save layouts: \(error)")
            return false
        }
    }
}
