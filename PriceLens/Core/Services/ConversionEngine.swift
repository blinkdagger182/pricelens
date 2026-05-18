import Foundation

struct ConversionEngine {
    let rates: CurrencyRateProviding

    init(rates: CurrencyRateProviding = CurrencyRateService()) {
        self.rates = rates
    }

    func convert(_ amount: Decimal, from source: String, to target: String) -> Decimal {
        let sourceRate = rates.rate(for: source).rateToMYR
        let targetRate = rates.rate(for: target).rateToMYR
        guard targetRate != 0 else { return 0 }
        return amount * sourceRate / targetRate
    }

    func rateDescription(from source: String, to target: String) -> String {
        let converted = convert(1, from: source, to: target)
        return "1 \(source) = \(CurrencyFormatter.string(converted, code: target))"
    }
}

