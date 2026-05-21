import CoreGraphics
import Foundation
import SwiftUI
import UIKit

enum ScannerUXState: Equatable {
    case loadingCamera
    case scannerUnavailable
    case scanning
    case pricesDetected
    case noPriceFound
    case permissionDenied
}

@MainActor
final class ScannerViewModel: ObservableObject {
    @Published var overlays: [PriceOverlayItem] = []
    @Published var state: ScannerUXState = .loadingCamera
    @Published var selectedOverlay: PriceOverlayItem?
    @Published var isFrozen = false
    @Published var usingFallbackRates = true
    @Published var scanProgress: CGFloat = 0

    private let parser = PriceParser()
    private let stabilizer = OverlayStabilizer()
    private let converter = ConversionEngine()
    private let rateService = CurrencyRateService.shared
    private let haptics = HapticsService()
    private var lastProcess = Date.distantPast
    private var lastFoundCount = 0
    private let firstDetectionInterval: TimeInterval = 0.08
    private let trackingUpdateInterval: TimeInterval = 0.16

    init() {
        usingFallbackRates = rateService.isUsingFallbackRates
    }

    func refreshRatesIfNeeded() async {
        await rateService.refreshIfNeeded()
        usingFallbackRates = rateService.isUsingFallbackRates
    }

    func process(recognized: [(String, CGRect)], travelCurrency: String, homeCurrency: String, containerSize: CGSize, force: Bool = false) {
        guard !isFrozen else { return }
        let now = Date()
        let throttle = overlays.isEmpty ? firstDetectionInterval : trackingUpdateInterval
        guard force || now.timeIntervalSince(lastProcess) > throttle else { return }
        lastProcess = now
        let parseInputs = expandedReceiptContext(from: recognized)
        let candidates = parseInputs.flatMap { parser.parse(text: $0.0, bounds: $0.1, selectedTravelCurrency: travelCurrency) }
        let nextOverlays = stabilizer.update(candidates: candidates, targetCurrency: homeCurrency, converter: converter, containerSize: containerSize)
        let nextState: ScannerUXState = nextOverlays.isEmpty ? .noPriceFound : .pricesDetected
        let nextProgress = scanProgress(for: nextOverlays, hasCandidates: !candidates.isEmpty, recognizedCount: recognized.count)
        guard nextOverlays != overlays || nextState != state || nextProgress != scanProgress else { return }
        let animation: Animation = overlays.isEmpty && !nextOverlays.isEmpty
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.24, dampingFraction: 0.84)
        withAnimation(animation) {
            overlays = nextOverlays
            state = nextState
            scanProgress = nextProgress
        }
        if overlays.count > lastFoundCount { haptics.success() }
        lastFoundCount = overlays.count
    }

    private func expandedReceiptContext(from recognized: [(String, CGRect)]) -> [(String, CGRect)] {
        let cleaned = recognized.compactMap { text, rect -> (String, CGRect)? in
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return (value, rect)
        }
        guard cleaned.count > 1 else { return cleaned }

        let lineBuckets = Dictionary(grouping: cleaned) { item in
            let midY = item.1.midY
            let lineHeight = max(item.1.height, 18)
            return Int((midY / lineHeight).rounded())
        }

        let combinedLines = lineBuckets.values.compactMap { items -> (String, CGRect)? in
            let sorted = items.sorted { $0.1.minX < $1.1.minX }
            guard sorted.count > 1 else { return nil }
            let text = sorted.map(\.0).joined(separator: " ")
            let bounds = sorted.dropFirst().reduce(sorted[0].1) { $0.union($1.1) }
            return (text, bounds)
        }

        return cleaned + combinedLines
    }

    private func scanProgress(for overlays: [PriceOverlayItem], hasCandidates: Bool, recognizedCount: Int) -> CGFloat {
        guard recognizedCount > 0 else { return 0 }
        guard hasCandidates else { return 0.16 }
        guard let bestOverlay = overlays.max(by: { lhs, rhs in
            if lhs.hitCount == rhs.hitCount { return lhs.confidence < rhs.confidence }
            return lhs.hitCount < rhs.hitCount
        }) else {
            return 0.42
        }

        if bestOverlay.confidence >= 0.90 || bestOverlay.hitCount >= 3 {
            return 1
        }
        if bestOverlay.hitCount >= 2 {
            return 0.82
        }
        return 0.58
    }

    func pruneStaleOverlays(homeCurrency: String, containerSize: CGSize) {
        let active = stabilizer.update(candidates: [], targetCurrency: homeCurrency, converter: converter, containerSize: containerSize)
        let nextProgress: CGFloat = active.isEmpty ? 0 : scanProgress
        guard active.count != overlays.count || nextProgress != scanProgress else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) {
            overlays = active
            scanProgress = nextProgress
            if overlays.isEmpty, state == .pricesDetected {
                state = .scanning
            }
        }
        lastFoundCount = overlays.count
    }

    func scannerBecameAvailable() {
        state = .scanning
    }

    func scannerUnavailable() {
        state = .scannerUnavailable
    }

    func permissionDenied() {
        state = .permissionDenied
    }

    func tap(_ overlay: PriceOverlayItem) {
        haptics.light()
        selectedOverlay = overlay
    }

    func historyItem(from overlay: PriceOverlayItem) -> ScanHistoryItem {
        ScanHistoryItem(
            originalAmount: overlay.amount,
            originalText: overlay.originalText,
            sourceCurrencyCode: overlay.sourceCurrencyCode,
            convertedAmount: overlay.convertedAmount,
            targetCurrencyCode: overlay.targetCurrencyCode,
            rateDescription: converter.rateDescription(from: overlay.sourceCurrencyCode, to: overlay.targetCurrencyCode),
            createdAt: Date(),
            note: nil
        )
    }
}
