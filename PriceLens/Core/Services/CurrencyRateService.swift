import Foundation

protocol CurrencyRateProviding {
    func rate(for code: String) -> ExchangeRate
}

struct CachedExchangeRatePayload: Codable {
    let updatedAt: Date
    let provider: String
    let effectiveDate: String
    let ratesToMYR: [String: Decimal]
}

final class CurrencyRateService: CurrencyRateProviding {
    static let shared = CurrencyRateService()

    private let rates: [String: Decimal] = [
        "MYR": 1.0, "JPY": 0.03067, "KRW": 0.00341, "SGD": 3.50,
        "THB": 0.13, "IDR": 0.00028, "USD": 4.70, "EUR": 5.10,
        "GBP": 5.95, "AUD": 3.10, "CAD": 3.45, "CNY": 0.65,
        "HKD": 0.60, "TWD": 0.145, "PHP": 0.080, "VND": 0.00018
    ]
    private let defaults: UserDefaults
    private let client: BackendRateClient
    private var cachedPayload: CachedExchangeRatePayload?

    init(defaults: UserDefaults = .standard, client: BackendRateClient = BackendRateClient()) {
        self.defaults = defaults
        self.client = client
        cachedPayload = Self.loadCachedPayload(defaults: defaults)
    }

    func rate(for code: String) -> ExchangeRate {
        if let cachedPayload, let rate = cachedPayload.ratesToMYR[code] {
            return ExchangeRate(currencyCode: code, rateToMYR: rate, updatedAt: cachedPayload.updatedAt, isFallback: false)
        }

        return ExchangeRate(currencyCode: code, rateToMYR: rates[code] ?? 1, updatedAt: Date(), isFallback: true)
    }

    var isUsingFallbackRates: Bool {
        cachedPayload == nil
    }

    var lastUpdatedAt: Date? {
        cachedPayload?.updatedAt
    }

    func refreshIfNeeded(force: Bool = false) async {
        if !force, let updatedAt = cachedPayload?.updatedAt, Calendar.current.isDateInToday(updatedAt) {
            return
        }

        do {
            let response = try await client.fetchLatestRates()
            let ratesToMYR = convertBackendRatesToMYR(response)
            let payload = CachedExchangeRatePayload(
                updatedAt: response.fetchedAt,
                provider: response.provider,
                effectiveDate: response.effectiveDate,
                ratesToMYR: ratesToMYR
            )
            cachedPayload = payload
            if let data = try? JSONEncoder().encode(payload) {
                defaults.set(data, forKey: AppStorageKeys.cachedExchangeRates)
            }
        } catch {
            print("Failed to refresh backend exchange rates: \(error.localizedDescription)")
        }
    }

    private func convertBackendRatesToMYR(_ response: BackendRatesResponse) -> [String: Decimal] {
        let ratesPerBase = response.rates
        let myrPerBase = ratesPerBase["MYR"] ?? 1
        var converted: [String: Decimal] = [:]

        for (code, unitsPerBase) in ratesPerBase where unitsPerBase > 0 {
            let rateToMYR = myrPerBase / unitsPerBase
            converted[code] = Decimal(rateToMYR)
        }
        converted["MYR"] = 1
        return converted
    }

    private static func loadCachedPayload(defaults: UserDefaults) -> CachedExchangeRatePayload? {
        guard let data = defaults.data(forKey: AppStorageKeys.cachedExchangeRates) else {
            return nil
        }
        return try? JSONDecoder().decode(CachedExchangeRatePayload.self, from: data)
    }
}
