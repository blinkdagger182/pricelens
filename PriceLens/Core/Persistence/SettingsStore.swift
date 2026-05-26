import Combine
import Foundation
import StoreKit

final class SettingsStore: ObservableObject {
    static let maxFavoriteCurrencyCount = 5

    @Published var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: AppStorageKeys.hasCompletedOnboarding) } }
    @Published var homeCurrencyCode: String { didSet { defaults.set(homeCurrencyCode, forKey: AppStorageKeys.homeCurrencyCode) } }
    @Published var travelCurrencyCode: String { didSet { defaults.set(travelCurrencyCode, forKey: AppStorageKeys.travelCurrencyCode) } }
    @Published var favoriteCurrencyCodes: [String] { didSet { saveFavoriteCurrencies() } }
    @Published var liveDetectionEnabled: Bool { didSet { defaults.set(liveDetectionEnabled, forKey: AppStorageKeys.liveDetectionEnabled) } }

    private let defaults: UserDefaults
    private let locationCurrencyService = LocationCurrencyService()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: AppStorageKeys.hasCompletedOnboarding)
        homeCurrencyCode = defaults.string(forKey: AppStorageKeys.homeCurrencyCode) ?? Locale.deviceCurrencyCode
        travelCurrencyCode = defaults.string(forKey: AppStorageKeys.travelCurrencyCode) ?? "JPY"
        favoriteCurrencyCodes = Self.loadFavoriteCurrencies(defaults: defaults)
        liveDetectionEnabled = defaults.object(forKey: AppStorageKeys.liveDetectionEnabled) as? Bool ?? true
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
        favoriteCurrencyCodes.removeAll { $0 == normalized }
        favoriteCurrencyCodes.insert(normalized, at: 0)
        favoriteCurrencyCodes = Array(favoriteCurrencyCodes.prefix(Self.maxFavoriteCurrencyCount))
    }

    @discardableResult
    func togglePinnedRate(_ code: String) -> Bool {
        let normalized = code.uppercased()
        if let index = favoriteCurrencyCodes.firstIndex(of: normalized) {
            favoriteCurrencyCodes.remove(at: index)
            return true
        } else {
            guard favoriteCurrencyCodes.count < Self.maxFavoriteCurrencyCount else { return false }
            favoriteCurrencyCodes.insert(normalized, at: 0)
            return true
        }
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

    func updateHomeCurrencyFromStorefrontIfNeeded() async {
        guard defaults.string(forKey: AppStorageKeys.homeCurrencyCode) == nil else { return }
        guard let countryCode = await Storefront.current?.countryCode,
              let currencyCode = Locale.currentCurrencyCode(forRegionCode: countryCode) else { return }

        await MainActor.run {
            guard self.defaults.string(forKey: AppStorageKeys.homeCurrencyCode) == nil else { return }
            self.homeCurrencyCode = currencyCode
            self.addFavoriteCurrency(currencyCode)
        }
    }

    private func saveFavoriteCurrencies() {
        defaults.set(favoriteCurrencyCodes, forKey: AppStorageKeys.favoriteCurrencyCodes)
    }

    private static func loadFavoriteCurrencies(defaults: UserDefaults) -> [String] {
        if let codes = defaults.stringArray(forKey: AppStorageKeys.favoriteCurrencyCodes), !codes.isEmpty {
            return Array(codes.map { $0.uppercased() }.prefix(maxFavoriteCurrencyCount))
        }
        return Array([Locale.deviceCurrencyCode, "MYR", "USD", "JPY", "SGD"].map { $0.uppercased() }.uniqued().prefix(maxFavoriteCurrencyCount))
    }

}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
