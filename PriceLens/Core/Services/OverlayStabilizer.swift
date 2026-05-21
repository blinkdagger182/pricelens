import CoreGraphics
import Foundation

final class OverlayStabilizer {
    private var overlays: [PriceOverlayItem] = []
    private let keepAlive: TimeInterval = 1.2

    var currentOverlays: [PriceOverlayItem] {
        overlays
    }

    func update(candidates: [ParsedPriceCandidate], targetCurrency: String, converter: ConversionEngine, containerSize: CGSize) -> [PriceOverlayItem] {
        let now = Date()
        overlays.removeAll { now.timeIntervalSince($0.lastSeenAt) > keepAlive }

        for candidate in candidates where candidate.bounds.width > 20 && candidate.bounds.height > 8 {
            let converted = converter.convert(candidate.amount, from: candidate.currencyCode, to: targetCurrency)
            if let index = overlays.firstIndex(where: { isSame($0, candidate) }) {
                var item = overlays[index]
                item.bounds = smoothedRect(from: item.bounds, to: candidate.bounds)
                item.displayPoint = displayPoint(for: item.bounds, containerSize: containerSize)
                item.confidence = max(item.confidence, candidate.confidence)
                item.convertedAmount = converted
                item.lastSeenAt = now
                item.hitCount += 1
                if item.hitCount >= 2 || candidate.confidence >= 0.90 {
                    item.originalText = candidate.originalText
                    item.amount = candidate.amount
                }
                overlays[index] = item
            } else {
                overlays.append(.init(
                    id: UUID(),
                    originalText: candidate.originalText,
                    amount: candidate.amount,
                    sourceCurrencyCode: candidate.currencyCode,
                    targetCurrencyCode: targetCurrency,
                    convertedAmount: converted,
                    bounds: candidate.bounds,
                    displayPoint: displayPoint(for: candidate.bounds, containerSize: containerSize),
                    confidence: candidate.confidence,
                    lastSeenAt: now,
                    hitCount: 1
                ))
            }
        }

        overlays = mergeDuplicates(overlays)
        return overlays.sorted { lhs, rhs in
            if lhs.confidence == rhs.confidence { return lhs.hitCount > rhs.hitCount }
            return lhs.confidence > rhs.confidence
        }.prefix(5).map { $0 }
    }

    private func isSame(_ item: PriceOverlayItem, _ candidate: ParsedPriceCandidate) -> Bool {
        let close = hypot(item.bounds.midX - candidate.bounds.midX, item.bounds.midY - candidate.bounds.midY) < 90
        return item.sourceCurrencyCode == candidate.currencyCode && item.amount == candidate.amount && close
    }

    private func smoothedRect(from old: CGRect, to new: CGRect) -> CGRect {
        let alpha = 0.35
        return CGRect(
            x: old.origin.x + (new.origin.x - old.origin.x) * alpha,
            y: old.origin.y + (new.origin.y - old.origin.y) * alpha,
            width: old.width + (new.width - old.width) * alpha,
            height: old.height + (new.height - old.height) * alpha
        )
    }

    private func displayPoint(for bounds: CGRect, containerSize: CGSize) -> CGPoint {
        let cardWidth: CGFloat = 154
        let cardHeight: CGFloat = 76
        var x = bounds.midX
        var y = bounds.maxY + cardHeight * 0.58 + 12
        if y + cardHeight / 2 > containerSize.height - 92 {
            y = bounds.minY - cardHeight * 0.58 - 12
        }
        x = min(max(x, cardWidth / 2 + 12), max(cardWidth / 2 + 12, containerSize.width - cardWidth / 2 - 12))
        y = min(max(y, 110), max(110, containerSize.height - 110))
        return CGPoint(x: x, y: y)
    }

    private func mergeDuplicates(_ items: [PriceOverlayItem]) -> [PriceOverlayItem] {
        var result: [PriceOverlayItem] = []
        for item in items {
            if result.contains(where: { $0.amount == item.amount && $0.sourceCurrencyCode == item.sourceCurrencyCode && hypot($0.bounds.midX - item.bounds.midX, $0.bounds.midY - item.bounds.midY) < 48 }) {
                continue
            }
            result.append(item)
        }
        return result
    }
}
