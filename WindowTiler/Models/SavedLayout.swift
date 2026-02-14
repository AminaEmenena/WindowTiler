import Foundation

/// Represents a single window's position within a saved layout
struct WindowPosition: Codable, Identifiable {
    var id: String { "\(bundleID)-\(Int(frame.origin.x))-\(Int(frame.origin.y))" }

    let bundleID: String
    let appName: String
    let frame: CGRect

    enum CodingKeys: String, CodingKey {
        case bundleID
        case appName
        case frame
    }

    init(bundleID: String, appName: String, frame: CGRect) {
        self.bundleID = bundleID
        self.appName = appName
        self.frame = frame
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        appName = try container.decode(String.self, forKey: .appName)

        let frameDict = try container.decode([String: CGFloat].self, forKey: .frame)
        frame = CGRect(
            x: frameDict["x"] ?? 0,
            y: frameDict["y"] ?? 0,
            width: frameDict["width"] ?? 0,
            height: frameDict["height"] ?? 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleID, forKey: .bundleID)
        try container.encode(appName, forKey: .appName)

        let frameDict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.width,
            "height": frame.height
        ]
        try container.encode(frameDict, forKey: .frame)
    }
}

/// Represents a saved window layout configuration
struct SavedLayout: Codable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let windowPositions: [WindowPosition]

    init(id: UUID = UUID(), name: String, windowPositions: [WindowPosition]) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.windowPositions = windowPositions
    }

    var windowCount: Int {
        windowPositions.count
    }

    var uniqueAppCount: Int {
        Set(windowPositions.map { $0.bundleID }).count
    }
}
