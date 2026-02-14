import Foundation
import ServiceManagement

@MainActor
class LaunchAtLoginService: ObservableObject {
    static let shared = LaunchAtLoginService()

    @Published private(set) var isEnabled: Bool = false

    private init() {
        updateStatus()
    }

    func updateStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to \(isEnabled ? "disable" : "enable") launch at login: \(error)")
        }
        updateStatus()
    }
}
