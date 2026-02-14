import Foundation
import Combine

class GroupStorage: ObservableObject {
    static let shared = GroupStorage()

    @Published private(set) var groups: [AppGroup] = []

    private let storageKey = "WindowTiler.AppGroups"

    init() {
        loadGroups()
    }

    // MARK: - Public Methods

    func saveGroup(name: String, bundleIdentifiers: [String]) {
        let group = AppGroup(name: name, bundleIdentifiers: bundleIdentifiers)
        groups.append(group)
        persistGroups()
    }

    func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        persistGroups()
    }

    func updateGroup(_ group: AppGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            persistGroups()
        }
    }

    func getGroup(id: UUID) -> AppGroup? {
        groups.first { $0.id == id }
    }

    // MARK: - Private Methods

    private func loadGroups() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            groups = []
            return
        }

        do {
            let decoder = JSONDecoder()
            groups = try decoder.decode([AppGroup].self, from: data)
        } catch {
            print("Failed to load groups: \(error)")
            groups = []
        }
    }

    private func persistGroups() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(groups)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save groups: \(error)")
        }
    }
}
