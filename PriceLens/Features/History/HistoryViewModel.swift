import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    func grouped(_ items: [ScanHistoryItem]) -> [(String, [ScanHistoryItem])] {
        let calendar = Calendar.current
        let today = items.filter { calendar.isDateInToday($0.createdAt) }
        let older = items.filter { !calendar.isDateInToday($0.createdAt) }
        var result: [(String, [ScanHistoryItem])] = []
        if !today.isEmpty { result.append(("Today", today)) }
        if !older.isEmpty { result.append(("Earlier", older)) }
        return result
    }
}

