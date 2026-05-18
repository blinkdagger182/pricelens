import Combine
import Foundation

final class ScanHistoryStore: ObservableObject {
    @Published private(set) var items: [ScanHistoryItem] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ item: ScanHistoryItem) {
        guard !items.contains(where: { $0.originalText == item.originalText && abs($0.createdAt.timeIntervalSince(item.createdAt)) < 2 }) else { return }
        items.insert(item, at: 0)
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: AppStorageKeys.historyItems) else { return }
        items = (try? JSONDecoder().decode([ScanHistoryItem].self, from: data)) ?? []
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(items), forKey: AppStorageKeys.historyItems)
    }
}

