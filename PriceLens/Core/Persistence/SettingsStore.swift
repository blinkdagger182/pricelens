import Combine
import Foundation

final class SettingsStore: ObservableObject {
    @Published var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: AppStorageKeys.hasCompletedOnboarding) } }
    @Published var homeCurrencyCode: String { didSet { defaults.set(homeCurrencyCode, forKey: AppStorageKeys.homeCurrencyCode) } }
    @Published var travelCurrencyCode: String { didSet { defaults.set(travelCurrencyCode, forKey: AppStorageKeys.travelCurrencyCode) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: AppStorageKeys.hasCompletedOnboarding)
        homeCurrencyCode = defaults.string(forKey: AppStorageKeys.homeCurrencyCode) ?? "MYR"
        travelCurrencyCode = defaults.string(forKey: AppStorageKeys.travelCurrencyCode) ?? "JPY"
    }

    var homeCurrency: Currency { Currency.find(homeCurrencyCode) }
    var travelCurrency: Currency { Currency.find(travelCurrencyCode) }
}

