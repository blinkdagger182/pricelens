import Foundation

struct Currency: Identifiable, Codable, Hashable {
    let code: String
    let name: String
    let symbol: String
    let flag: String
    let supportsDecimals: Bool
    var id: String { code }

    static let supported: [Currency] = [
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

    static func find(_ code: String) -> Currency {
        supported.first { $0.code == code } ?? supported[0]
    }
}

