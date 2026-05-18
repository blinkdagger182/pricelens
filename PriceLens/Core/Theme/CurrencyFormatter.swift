import Foundation

enum CurrencyFormatter {
    static func string(_ amount: Decimal, code: String) -> String {
        let currency = Currency.find(code)
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = currency.supportsDecimals ? 2 : 0
        formatter.maximumFractionDigits = currency.supportsDecimals ? 2 : 0
        formatter.groupingSeparator = code == "IDR" ? "." : ","
        formatter.decimalSeparator = "."
        let value = formatter.string(from: number) ?? "\(number)"
        switch code {
        case "MYR": return "RM \(value)"
        case "JPY": return "¥\(value)"
        case "KRW": return "₩\(value)"
        case "SGD": return "S$\(value)"
        case "USD": return "$\(value)"
        case "EUR": return "€\(value)"
        case "GBP": return "£\(value)"
        case "IDR": return "Rp \(value)"
        default: return "\(currency.symbol)\(value)"
        }
    }
}

