import Combine
import Foundation

final class SettingsStore: ObservableObject {
    @Published var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: AppStorageKeys.hasCompletedOnboarding) } }
    @Published var homeCurrencyCode: String { didSet { defaults.set(homeCurrencyCode, forKey: AppStorageKeys.homeCurrencyCode) } }
    @Published var travelCurrencyCode: String { didSet { defaults.set(travelCurrencyCode, forKey: AppStorageKeys.travelCurrencyCode) } }
    @Published var favoriteCurrencyCodes: [String] { didSet { saveFavoriteCurrencies() } }

    private let defaults: UserDefaults
    private let locationCurrencyService = LocationCurrencyService()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: AppStorageKeys.hasCompletedOnboarding)
        homeCurrencyCode = defaults.string(forKey: AppStorageKeys.homeCurrencyCode) ?? Locale.deviceCurrencyCode
        travelCurrencyCode = defaults.string(forKey: AppStorageKeys.travelCurrencyCode) ?? "JPY"
        favoriteCurrencyCodes = Self.loadFavoriteCurrencies(defaults: defaults)
    }

    var homeCurrency: Currency { Currency.find(homeCurrencyCode) }
    var travelCurrency: Currency { Currency.find(travelCurrencyCode) }

    var favoriteCurrencies: [Currency] {
        Currency.currencies(for: favoriteCurrencyCodes)
    }

    func selectHomeCurrency(_ code: String) {
        homeCurrencyCode = code.uppercased()
        addFavoriteCurrency(code)
    }

    func selectTravelCurrency(_ code: String) {
        travelCurrencyCode = code.uppercased()
        addFavoriteCurrency(code)
    }

    func swapCurrencies() {
        let currentHome = homeCurrencyCode
        homeCurrencyCode = travelCurrencyCode
        travelCurrencyCode = currentHome
        addFavoriteCurrency(homeCurrencyCode)
        addFavoriteCurrency(travelCurrencyCode)
    }

    func addFavoriteCurrency(_ code: String) {
        let normalized = code.uppercased()
        guard !favoriteCurrencyCodes.contains(normalized) else { return }
        favoriteCurrencyCodes.append(normalized)
    }

    func updateTravelCurrencyFromCurrentLocationIfNeeded() async {
        guard !defaults.bool(forKey: AppStorageKeys.hasAutoDetectedTravelCurrency) else { return }
        do {
            let code = try await locationCurrencyService.currentCurrencyCode()
            await MainActor.run {
                travelCurrencyCode = code
                addFavoriteCurrency(code)
                defaults.set(true, forKey: AppStorageKeys.hasAutoDetectedTravelCurrency)
            }
        } catch {
            defaults.set(true, forKey: AppStorageKeys.hasAutoDetectedTravelCurrency)
            if !(error is LocationCurrencyError) {
                print("Could not detect travel currency from location: \(error.localizedDescription)")
            }
        }
    }

    private func saveFavoriteCurrencies() {
        defaults.set(favoriteCurrencyCodes, forKey: AppStorageKeys.favoriteCurrencyCodes)
    }

    private static func loadFavoriteCurrencies(defaults: UserDefaults) -> [String] {
        if let codes = defaults.stringArray(forKey: AppStorageKeys.favoriteCurrencyCodes), !codes.isEmpty {
            return codes.map { $0.uppercased() }
        }
        return Array(Set([Locale.deviceCurrencyCode, "MYR", "USD", "JPY", "SGD", "EUR", "GBP"])).sorted()
    }
}
