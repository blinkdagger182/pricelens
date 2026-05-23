import Foundation
import StoreKit

struct OnboardingDemoConversion: Equatable {
    let sourceCode: String
    let sourceAmount: Decimal
    let targetCode: String
    let convertedAmount: Decimal

    static let fallback = make(forStorefrontCountry: nil)

    var sourceText: String {
        CurrencyFormatter.string(sourceAmount, code: sourceCode)
    }

    var convertedText: String {
        CurrencyFormatter.string(convertedAmount, code: targetCode)
    }

    var routeText: String {
        "\(sourceCode) → \(targetCode)"
    }

    static func current() async -> OnboardingDemoConversion {
        make(forStorefrontCountry: await Storefront.current?.countryCode)
    }

    static func make(forStorefrontCountry countryCode: String?) -> OnboardingDemoConversion {
        let sourceAmount = Decimal(12_800)
        let targetCode = targetCurrencyCode(forStorefrontCountry: countryCode)
        return OnboardingDemoConversion(
            sourceCode: "JPY",
            sourceAmount: sourceAmount,
            targetCode: targetCode,
            convertedAmount: ConversionEngine().convert(sourceAmount, from: "JPY", to: targetCode)
        )
    }

    private static func targetCurrencyCode(forStorefrontCountry countryCode: String?) -> String {
        guard let countryCode = countryCode?.uppercased() else { return "USD" }

        if countryCode == "MY" { return "MYR" }
        if countryCode == "US" { return "USD" }
        if countryCode == "GB" { return "GBP" }
        if countryCode == "AU" { return "AUD" }
        if euroStorefrontCountries.contains(countryCode) { return "EUR" }
        return "USD"
    }

    private static let euroStorefrontCountries: Set<String> = [
        "AT", "BE", "HR", "CY", "EE", "FI", "FR", "DE", "GR", "IE",
        "IT", "LV", "LT", "LU", "MT", "NL", "PT", "SK", "SI", "ES"
    ]
}
