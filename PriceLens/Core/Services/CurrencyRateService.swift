import Foundation

protocol CurrencyRateProviding {
    func rate(for code: String) -> ExchangeRate
}

struct CurrencyRateService: CurrencyRateProviding {
    private let rates: [String: Decimal] = [
        "MYR": 1.0, "JPY": 0.03067, "KRW": 0.00341, "SGD": 3.50,
        "THB": 0.13, "IDR": 0.00028, "USD": 4.70, "EUR": 5.10,
        "GBP": 5.95, "AUD": 3.10, "CAD": 3.45, "CNY": 0.65,
        "HKD": 0.60, "TWD": 0.145, "PHP": 0.080, "VND": 0.00018
    ]

    func rate(for code: String) -> ExchangeRate {
        ExchangeRate(currencyCode: code, rateToMYR: rates[code] ?? 1, updatedAt: Date(), isFallback: true)
    }
}

