import Foundation

struct ExchangeRate: Codable, Hashable {
    let currencyCode: String
    let rateToMYR: Decimal
    let updatedAt: Date
    let isFallback: Bool
}

