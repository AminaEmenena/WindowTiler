import Foundation
import Combine

class SettingsService: ObservableObject {
    static let shared = SettingsService()

    @Published var windowGap: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(windowGap), forKey: "WindowTiler.windowGap")
        }
    }

    private init() {
        let savedGap = UserDefaults.standard.double(forKey: "WindowTiler.windowGap")
        self.windowGap = savedGap > 0 ? CGFloat(savedGap) : 4.0
    }
}
