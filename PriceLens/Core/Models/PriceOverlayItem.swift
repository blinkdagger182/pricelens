import CoreGraphics
import Foundation

struct PriceOverlayItem: Identifiable, Equatable {
    var id: UUID
    var originalText: String
    var amount: Decimal
    var sourceCurrencyCode: String
    var targetCurrencyCode: String
    var convertedAmount: Decimal
    var bounds: CGRect
    var displayPoint: CGPoint
    var confidence: Double
    var lastSeenAt: Date
    var hitCount: Int
}

