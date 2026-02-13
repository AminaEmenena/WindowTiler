import Foundation
import AppKit

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let name: String
    let ownerName: String
    let ownerPID: pid_t
    let bounds: CGRect
    let isOnScreen: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct AppWindows: Identifiable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    var windows: [WindowInfo]
    var isSelected: Bool = false

    var windowCount: Int {
        windows.count
    }
}
