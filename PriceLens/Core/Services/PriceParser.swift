import CoreGraphics
import Foundation

struct PriceParser {
    func parse(text: String, bounds: CGRect, selectedTravelCurrency: String) -> [ParsedPriceCandidate] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 1, bounds.width >= 24, bounds.height >= 10 else { return [] }
        guard !isBarcodeLike(cleaned) else { return [] }

        let explicitCode = Currency.supported.map(\.code).first { cleaned.uppercased().contains($0) }
        let symbolCurrency = currencyFromSymbol(in: cleaned, selectedTravelCurrency: selectedTravelCurrency)
        let currency = explicitCode ?? symbolCurrency ?? selectedTravelCurrency
        let confidence: Double = explicitCode != nil ? 0.95 : (symbolCurrency != nil ? 0.90 : inferredConfidence(cleaned))
        guard confidence >= 0.50 else { return [] }

        return numericTokens(in: cleaned, currency: currency, explicit: explicitCode != nil || symbolCurrency != nil).compactMap { token in
            guard let amount = decimal(from: token, currency: currency) else { return nil }
            guard amount > 0 else { return nil }
            return ParsedPriceCandidate(originalText: cleaned, amount: amount, currencyCode: currency, confidence: confidence, bounds: bounds)
        }
    }

    private func currencyFromSymbol(in text: String, selectedTravelCurrency: String) -> String? {
        let upper = text.uppercased()
        if upper.contains("S$") { return "SGD" }
        if upper.contains("RM") { return "MYR" }
        if upper.contains("RP") { return "IDR" }
        if upper.contains("₩") { return "KRW" }
        if upper.contains("€") { return "EUR" }
        if upper.contains("£") { return "GBP" }
        if upper.contains("฿") { return "THB" }
        if upper.contains("₱") { return "PHP" }
        if upper.contains("₫") { return "VND" }
        if upper.contains("円") { return "JPY" }
        if upper.contains("¥") { return selectedTravelCurrency == "CNY" ? "CNY" : "JPY" }
        if upper.contains("$") {
            return ["USD", "SGD", "AUD", "CAD", "HKD", "NZD"].contains(selectedTravelCurrency) ? selectedTravelCurrency : "USD"
        }
        return nil
    }

    private func inferredConfidence(_ text: String) -> Double {
        let hasSeparator = text.contains(",") || text.contains(".")
        let digitCount = text.filter(\.isNumber).count
        if digitCount >= 2 && digitCount <= 8 && hasSeparator { return 0.75 }
        if digitCount >= 1 && digitCount <= 5 { return 0.50 }
        return 0
    }

    private func numericTokens(in text: String, currency: String, explicit: Bool) -> [String] {
        let pattern = #"(?<!\d)(\d{1,3}(?:[,.]\d{3})*(?:[,.]\d{2})?|\d+(?:[,.]\d{2})?)(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            let value = String(text[range])
            let digits = value.filter(\.isNumber).count
            if !explicit && digits > 8 { return nil }
            if !explicit && looksLikeYear(value) { return nil }
            return value
        }
    }

    private func decimal(from token: String, currency: String) -> Decimal? {
        let zeroDecimal = !Currency.find(currency).supportsDecimals
        var normalized = token
        if zeroDecimal {
            normalized = token.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
        } else if token.contains(",") && !token.contains(".") {
            let parts = token.split(separator: ",")
            normalized = parts.last?.count == 2 ? token.replacingOccurrences(of: ",", with: ".") : token.replacingOccurrences(of: ",", with: "")
        } else {
            normalized = token.replacingOccurrences(of: ",", with: "")
        }
        return Decimal(string: normalized)
    }

    private func isBarcodeLike(_ text: String) -> Bool {
        let digits = text.filter(\.isNumber)
        return digits.count >= 9 && Double(digits.count) / Double(max(text.count, 1)) > 0.85
    }

    private func looksLikeYear(_ value: String) -> Bool {
        guard let intValue = Int(value) else { return false }
        return intValue >= 1900 && intValue <= 2099
    }
}
