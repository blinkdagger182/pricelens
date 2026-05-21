import Foundation

protocol CurrencyRateProviding {
    func rate(for code: String) -> ExchangeRate
}

struct CachedExchangeRatePayload: Codable {
    let updatedAt: Date
    let nextUpdateAt: Date?
    let fetchedAt: Date
    let providerLastUpdateAt: Date?
    let providerNextUpdateAt: Date?
    let providerLastUpdateUnix: Int?
    let providerNextUpdateUnix: Int?
    let provider: String
    let effectiveDate: String
    let ratesToMYR: [String: Decimal]

    init(
        updatedAt: Date,
        nextUpdateAt: Date?,
        fetchedAt: Date,
        providerLastUpdateAt: Date?,
        providerNextUpdateAt: Date?,
        providerLastUpdateUnix: Int?,
        providerNextUpdateUnix: Int?,
        provider: String,
        effectiveDate: String,
        ratesToMYR: [String: Decimal]
    ) {
        self.updatedAt = updatedAt
        self.nextUpdateAt = nextUpdateAt
        self.fetchedAt = fetchedAt
        self.providerLastUpdateAt = providerLastUpdateAt
        self.providerNextUpdateAt = providerNextUpdateAt
        self.providerLastUpdateUnix = providerLastUpdateUnix
        self.providerNextUpdateUnix = providerNextUpdateUnix
        self.provider = provider
        self.effectiveDate = effectiveDate
        self.ratesToMYR = ratesToMYR
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        nextUpdateAt = try container.decodeIfPresent(Date.self, forKey: .nextUpdateAt)
        fetchedAt = try container.decodeIfPresent(Date.self, forKey: .fetchedAt) ?? updatedAt
        providerLastUpdateAt = try container.decodeIfPresent(Date.self, forKey: .providerLastUpdateAt)
        providerNextUpdateAt = try container.decodeIfPresent(Date.self, forKey: .providerNextUpdateAt)
        providerLastUpdateUnix = try container.decodeIfPresent(Int.self, forKey: .providerLastUpdateUnix)
        providerNextUpdateUnix = try container.decodeIfPresent(Int.self, forKey: .providerNextUpdateUnix)
        provider = try container.decode(String.self, forKey: .provider)
        effectiveDate = try container.decode(String.self, forKey: .effectiveDate)
        ratesToMYR = try container.decode([String: Decimal].self, forKey: .ratesToMYR)
    }
}

struct RateStatusSnapshot: Equatable {
    let isOfficial: Bool
    let provider: String
    let updatedAt: Date?
    let nextUpdateAt: Date?
    let fetchedAt: Date?
    let providerLastUpdateUnix: Int?
    let providerNextUpdateUnix: Int?
    let effectiveDate: String?
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

    var statusSnapshot: RateStatusSnapshot {
        guard let cachedPayload else {
            return RateStatusSnapshot(
                isOfficial: false,
                provider: "Local fallback",
                updatedAt: nil,
                nextUpdateAt: nil,
                fetchedAt: nil,
                providerLastUpdateUnix: nil,
                providerNextUpdateUnix: nil,
                effectiveDate: nil
            )
        }

        return RateStatusSnapshot(
            isOfficial: true,
            provider: cachedPayload.provider,
            updatedAt: cachedPayload.providerLastUpdateAt ?? cachedPayload.updatedAt,
            nextUpdateAt: cachedPayload.providerNextUpdateAt ?? cachedPayload.nextUpdateAt,
            fetchedAt: cachedPayload.fetchedAt,
            providerLastUpdateUnix: cachedPayload.providerLastUpdateUnix,
            providerNextUpdateUnix: cachedPayload.providerNextUpdateUnix,
            effectiveDate: cachedPayload.effectiveDate
        )
    }

    var availableCurrencyCodes: [String] {
        let cachedCodes = cachedPayload?.ratesToMYR.keys.map { $0.uppercased() } ?? []
        if !cachedCodes.isEmpty {
            return Array(Set(cachedCodes)).sorted()
        }
        let defaults = rates.keys.map { $0.uppercased() }
        return Array(Set(defaults)).sorted()
    }

    func refreshIfNeeded(force: Bool = false) async {
        if !force, let nextUpdateAt = cachedPayload?.nextUpdateAt, nextUpdateAt > Date() {
            return
        }

        do {
            let response = try await client.fetchLatestRates()
            let ratesToMYR = convertBackendRatesToMYR(response)
            let payload = CachedExchangeRatePayload(
                updatedAt: response.providerLastUpdateAt ?? response.fetchedAt,
                nextUpdateAt: response.providerNextUpdateAt ?? response.nextUpdateAt,
                fetchedAt: response.fetchedAt,
                providerLastUpdateAt: response.providerLastUpdateAt,
                providerNextUpdateAt: response.providerNextUpdateAt,
                providerLastUpdateUnix: response.providerLastUpdateUnix,
                providerNextUpdateUnix: response.providerNextUpdateUnix,
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
