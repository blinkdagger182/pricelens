import Foundation

struct ScanHistoryItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let originalAmount: Decimal
    let originalText: String
    let sourceCurrencyCode: String
    let convertedAmount: Decimal
    let targetCurrencyCode: String
    let rateDescription: String
    let createdAt: Date
    var note: String?
}

