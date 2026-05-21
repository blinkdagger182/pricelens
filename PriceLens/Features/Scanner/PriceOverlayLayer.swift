import SwiftUI

struct PriceOverlayLayer: View {
    let detections: [PriceDetectionItem]
    let items: [PriceOverlayItem]
    var onTap: (PriceOverlayItem) -> Void

    var body: some View {
        GeometryReader { proxy in
            let layouts = layoutItems(in: proxy.size)
            ZStack {
                ForEach(detections) { detection in
                    PriceDetectionBracket(detection: detection)
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
                ForEach(layouts) { layout in
                    PriceOverlayCard(item: layout.item)
                        .position(layout.cardCenter)
                        .onTapGesture { onTap(layout.item) }
                        .transition(.scale(scale: 0.88).combined(with: .opacity))
                }
            }
        }
    }

    private func layoutItems(in size: CGSize) -> [LaidOutPriceOverlay] {
        let sorted = items.sorted { lhs, rhs in
            if lhs.confidence == rhs.confidence { return lhs.hitCount > rhs.hitCount }
            return lhs.confidence > rhs.confidence
        }
        let priceRects = sorted.map { $0.bounds.insetBy(dx: -12, dy: -12) }
        var occupiedCardRects: [CGRect] = []

        return sorted.map { item in
            let center = bestCardCenter(
                for: item,
                in: size,
                priceRects: priceRects.filter { !$0.intersects(item.bounds.insetBy(dx: -4, dy: -4)) },
                occupiedCardRects: occupiedCardRects
            )
            let rect = cardRect(center: center).insetBy(dx: -8, dy: -8)
            occupiedCardRects.append(rect)
            return LaidOutPriceOverlay(item: item, cardCenter: center)
        }
    }

    private func bestCardCenter(
        for item: PriceOverlayItem,
        in size: CGSize,
        priceRects: [CGRect],
        occupiedCardRects: [CGRect]
    ) -> CGPoint {
        let candidates = candidateCenters(for: item.bounds, in: size)
        let blockers = priceRects + occupiedCardRects
        if let clear = candidates.first(where: { center in
            let rect = cardRect(center: center)
            return blockers.allSatisfy { !rect.intersects($0) }
        }) {
            return clear
        }

        return candidates.min { lhs, rhs in
            collisionScore(for: cardRect(center: lhs), against: blockers) < collisionScore(for: cardRect(center: rhs), against: blockers)
        } ?? item.displayPoint
    }

    private func candidateCenters(for bounds: CGRect, in size: CGSize) -> [CGPoint] {
        let cardWidth = PriceOverlayCard.metrics.width
        let cardHeight = PriceOverlayCard.metrics.height
        let gap: CGFloat = 14
        let raw = [
            CGPoint(x: bounds.midX, y: bounds.maxY + cardHeight / 2 + gap),
            CGPoint(x: bounds.midX, y: bounds.minY - cardHeight / 2 - gap),
            CGPoint(x: bounds.minX - cardWidth / 2 - gap, y: bounds.midY),
            CGPoint(x: bounds.maxX + cardWidth / 2 + gap, y: bounds.midY),
            CGPoint(x: bounds.midX - cardWidth * 0.45, y: bounds.maxY + cardHeight / 2 + gap),
            CGPoint(x: bounds.midX + cardWidth * 0.45, y: bounds.maxY + cardHeight / 2 + gap),
            CGPoint(x: bounds.midX - cardWidth * 0.45, y: bounds.minY - cardHeight / 2 - gap),
            CGPoint(x: bounds.midX + cardWidth * 0.45, y: bounds.minY - cardHeight / 2 - gap)
        ]

        return raw.map { point in
            CGPoint(
                x: min(max(point.x, cardWidth / 2 + 12), max(cardWidth / 2 + 12, size.width - cardWidth / 2 - 12)),
                y: min(max(point.y, 112), max(112, size.height - 112))
            )
        }
    }

    private func cardRect(center: CGPoint) -> CGRect {
        CGRect(
            x: center.x - PriceOverlayCard.metrics.width / 2,
            y: center.y - PriceOverlayCard.metrics.height / 2,
            width: PriceOverlayCard.metrics.width,
            height: PriceOverlayCard.metrics.height
        )
    }

    private func collisionScore(for rect: CGRect, against blockers: [CGRect]) -> CGFloat {
        blockers.reduce(CGFloat.zero) { score, blocker in
            guard rect.intersects(blocker) else { return score }
            return score + rect.intersection(blocker).width * rect.intersection(blocker).height
        }
    }
}

private struct LaidOutPriceOverlay: Identifiable {
    var id: UUID { item.id }
    let item: PriceOverlayItem
    let cardCenter: CGPoint
}

private struct PriceDetectionBracket: View {
    let detection: PriceDetectionItem

    private var size: CGSize {
        CGSize(width: max(detection.bounds.width, 44), height: max(detection.bounds.height, 28))
    }

    var body: some View {
        ZStack {
            ScannerCorners(color: .white.opacity(0.92), lineWidth: 3)
        }
        .frame(width: size.width, height: size.height)
        .position(x: detection.bounds.midX, y: detection.bounds.midY)
    }
}
