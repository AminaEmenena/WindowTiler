import Foundation

struct AppGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var bundleIdentifiers: [String]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, bundleIdentifiers: [String], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.bundleIdentifiers = bundleIdentifiers
        self.createdAt = createdAt
    }
}
