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

    private let parser = PriceParser()
    private let stabilizer = OverlayStabilizer()
    private let converter = ConversionEngine()
    private let rateService = CurrencyRateService.shared
    private let haptics = HapticsService()
    private var lastProcess = Date.distantPast
    private var lastFoundCount = 0

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
        guard force || now.timeIntervalSince(lastProcess) > 0.22 else { return }
        lastProcess = now
        let candidates = recognized.flatMap { parser.parse(text: $0.0, bounds: $0.1, selectedTravelCurrency: travelCurrency) }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            overlays = stabilizer.update(candidates: candidates, targetCurrency: homeCurrency, converter: converter, containerSize: containerSize)
            state = overlays.isEmpty ? .noPriceFound : .pricesDetected
        }
        if overlays.count > lastFoundCount { haptics.success() }
        lastFoundCount = overlays.count
    }

    func pruneStaleOverlays(homeCurrency: String, containerSize: CGSize) {
        let active = stabilizer.update(candidates: [], targetCurrency: homeCurrency, converter: converter, containerSize: containerSize)
        guard active.count != overlays.count else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            overlays = active
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
