import CoreGraphics
import Foundation

struct ParsedPriceCandidate: Identifiable, Hashable {
    let id = UUID()
    let originalText: String
    let amount: Decimal
    let currencyCode: String
    let confidence: Double
    let bounds: CGRect
}

struct DetectedPrice: Identifiable, Hashable {
    let id = UUID()
    let originalText: String
    let amount: Decimal
    let currencyCode: String
    let bounds: CGRect
    let confidence: Double
}

