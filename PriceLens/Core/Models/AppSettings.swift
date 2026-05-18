import Foundation

struct AppSettings: Codable, Hashable {
    var hasCompletedOnboarding: Bool
    var homeCurrencyCode: String
    var travelCurrencyCode: String
}

