import Foundation

struct Currency: Identifiable, Codable, Hashable {
    let code: String
    let name: String
    let symbol: String
    let flag: String
    let supportsDecimals: Bool
    var id: String { code }

    static let defaultSupported: [Currency] = [
        .init(code: "MYR", name: "Malaysian Ringgit", symbol: "RM", flag: "🇲🇾", supportsDecimals: true),
        .init(code: "JPY", name: "Japanese Yen", symbol: "¥", flag: "🇯🇵", supportsDecimals: false),
        .init(code: "KRW", name: "Korean Won", symbol: "₩", flag: "🇰🇷", supportsDecimals: false),
        .init(code: "THB", name: "Thai Baht", symbol: "฿", flag: "🇹🇭", supportsDecimals: true),
        .init(code: "SGD", name: "Singapore Dollar", symbol: "S$", flag: "🇸🇬", supportsDecimals: true),
        .init(code: "IDR", name: "Indonesian Rupiah", symbol: "Rp", flag: "🇮🇩", supportsDecimals: false),
        .init(code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸", supportsDecimals: true),
        .init(code: "EUR", name: "Euro", symbol: "€", flag: "🇪🇺", supportsDecimals: true),
        .init(code: "GBP", name: "British Pound", symbol: "£", flag: "🇬🇧", supportsDecimals: true),
        .init(code: "AUD", name: "Australian Dollar", symbol: "A$", flag: "🇦🇺", supportsDecimals: true),
        .init(code: "CAD", name: "Canadian Dollar", symbol: "C$", flag: "🇨🇦", supportsDecimals: true),
        .init(code: "CNY", name: "Chinese Yuan", symbol: "¥", flag: "🇨🇳", supportsDecimals: true),
        .init(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$", flag: "🇭🇰", supportsDecimals: true),
        .init(code: "TWD", name: "Taiwan Dollar", symbol: "NT$", flag: "🇹🇼", supportsDecimals: true),
        .init(code: "PHP", name: "Philippine Peso", symbol: "₱", flag: "🇵🇭", supportsDecimals: true),
        .init(code: "VND", name: "Vietnamese Dong", symbol: "₫", flag: "🇻🇳", supportsDecimals: false)
    ]

    static var supported: [Currency] {
        currencies(for: CurrencyRateService.shared.availableCurrencyCodes)
    }

    static func find(_ code: String) -> Currency {
        make(code: code)
    }

    static func currencies(for codes: [String]) -> [Currency] {
        let normalized = Set(codes.map { $0.uppercased() })
        let source = normalized.isEmpty ? Set(defaultSupported.map(\.code)) : normalized
        return source.map(make(code:)).sorted { lhs, rhs in
            if lhs.code == "MYR" { return true }
            if rhs.code == "MYR" { return false }
            if lhs.code == "USD" { return true }
            if rhs.code == "USD" { return false }
            return lhs.code < rhs.code
        }
    }

    private static func make(code rawCode: String) -> Currency {
        let code = rawCode.uppercased()
        if let known = defaultSupported.first(where: { $0.code == code }) {
            return known
        }

        let locale = Locale.current
        let name = locale.localizedString(forCurrencyCode: code) ?? code
        let symbol = symbol(for: code)
        let flag = flag(for: code)
        return Currency(code: code, name: name, symbol: symbol, flag: flag, supportsDecimals: !zeroDecimalCurrencyCodes.contains(code))
    }

    private static func symbol(for code: String) -> String {
        Locale.availableIdentifiers
            .lazy
            .compactMap { identifier -> String? in
                let locale = Locale(identifier: identifier)
                guard locale.currency?.identifier == code else { return nil }
                return locale.currencySymbol
            }
            .first ?? code
    }

    private static func flag(for code: String) -> String {
        let region = Locale.availableIdentifiers
            .lazy
            .compactMap { identifier -> String? in
                let locale = Locale(identifier: identifier)
                guard locale.currency?.identifier == code else { return nil }
                return locale.region?.identifier
            }
            .first
        guard let region else { return "¤" }
        return region.unicodeScalars.reduce("") {
            guard let scalar = UnicodeScalar(127397 + $1.value) else { return $0 }
            return $0 + String(scalar)
        }
    }

    private static let zeroDecimalCurrencyCodes: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG", "RWF", "UGX", "VND", "VUV", "XAF", "XOF", "XPF", "IDR"
    ]
}

extension Locale {
    static var discoveredCurrencyCodes: [String] {
        Array(Set(availableIdentifiers.compactMap { Locale(identifier: $0).currency?.identifier })).sorted()
    }
}
