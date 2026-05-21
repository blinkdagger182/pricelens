import CoreMotion
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
    private var lastUsefulInputAt = Date.distantPast
    private let progressWindow = DetectionProgressWindow()
    private let motionManager = CMMotionManager()
    private var isDeviceStable = true
    private var lastSubjectRects: [CGRect] = []
    private var stableSubjectFrames = 0
    private let firstDetectionInterval: TimeInterval = 0.055
    private let candidateTrackingInterval: TimeInterval = 0.10
    private let stableTrackingInterval: TimeInterval = 0.20

    init() {
        usingFallbackRates = rateService.isUsingFallbackRates
        startMotionMonitoring()
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }

    func refreshRatesIfNeeded() async {
        await rateService.refreshIfNeeded()
        usingFallbackRates = rateService.isUsingFallbackRates
    }

    func process(recognized: [(String, CGRect)], travelCurrency: String, homeCurrency: String, containerSize: CGSize, force: Bool = false) {
        guard !isFrozen else { return }
        let now = Date()
        let subjectStable = isSubjectStable(recognized: recognized)
        guard isDeviceStable, subjectStable else {
            resetDetectionProgress()
            return
        }

        let parseInputs = expandedReceiptContext(from: recognized)
        let candidates = parseInputs.flatMap { parser.parse(text: $0.0, bounds: $0.1, selectedTravelCurrency: travelCurrency) }
        progressWindow.record(recognizedCount: recognized.count, candidates: candidates, overlays: overlays, at: now)
        if !recognized.isEmpty || !candidates.isEmpty || !overlays.isEmpty {
            lastUsefulInputAt = now
        }

        let progressiveScanProgress = progressWindow.progress(currentProgress: scanProgress, at: now)
        if progressiveScanProgress != scanProgress {
            withAnimation(.easeOut(duration: 0.12)) {
                scanProgress = progressiveScanProgress
            }
        }

        let throttle = processingInterval(hasCandidates: !candidates.isEmpty)
        guard force || now.timeIntervalSince(lastProcess) > throttle else { return }
        lastProcess = now
        let nextOverlays = stabilizer.update(candidates: candidates, targetCurrency: homeCurrency, converter: converter, containerSize: containerSize)
        let nextState: ScannerUXState = nextOverlays.isEmpty ? .noPriceFound : .pricesDetected
        progressWindow.record(recognizedCount: recognized.count, candidates: candidates, overlays: nextOverlays, at: now)
        let nextProgress = progressWindow.progress(currentProgress: scanProgress, at: now)
        guard nextOverlays != overlays || nextState != state || nextProgress != scanProgress else { return }
        let animation: Animation = overlays.isEmpty && !nextOverlays.isEmpty
            ? .easeOut(duration: 0.08)
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

        let lines = groupedLines(from: cleaned)
        let combinedLines = lines.compactMap { items -> (String, CGRect)? in
            let sorted = items.sorted { $0.1.minX < $1.1.minX }
            guard sorted.count > 1 else { return nil }
            let text = sorted.map(\.0).joined(separator: " ")
            let bounds = sorted.dropFirst().reduce(sorted[0].1) { $0.union($1.1) }
            return (text, bounds)
        }

        let adjacentPairs = lines.flatMap { items -> [(String, CGRect)] in
            let sorted = items.sorted { $0.1.minX < $1.1.minX }
            guard sorted.count > 1 else { return [] }
            return sorted.indices.dropLast().flatMap { index -> [(String, CGRect)] in
                let first = sorted[index]
                let second = sorted[index + 1]
                let gap = second.1.minX - first.1.maxX
                let maxGap = max(first.1.height, second.1.height) * 2.8
                guard gap >= -6, gap <= maxGap else { return [] }
                let pair = (first.0 + second.0, first.1.union(second.1))
                let spacedPair = ("\(first.0) \(second.0)", first.1.union(second.1))
                return [pair, spacedPair]
            }
        }

        return cleaned + adjacentPairs + combinedLines
    }

    private func groupedLines(from items: [(String, CGRect)]) -> [[(String, CGRect)]] {
        let sorted = items.sorted {
            if abs($0.1.midY - $1.1.midY) < 8 { return $0.1.minX < $1.1.minX }
            return $0.1.midY < $1.1.midY
        }
        return sorted.reduce(into: [[(String, CGRect)]]()) { groups, item in
            if let index = groups.indices.last {
                let group = groups[index]
                let averageMidY = group.map(\.1.midY).reduce(0, +) / CGFloat(group.count)
                let averageHeight = group.map(\.1.height).reduce(0, +) / CGFloat(group.count)
                let tolerance = max(12, min(34, averageHeight * 0.72))
                if abs(item.1.midY - averageMidY) <= tolerance {
                    groups[index].append(item)
                    return
                }
            }
            groups.append([item])
        }
    }

    private func processingInterval(hasCandidates: Bool) -> TimeInterval {
        if overlays.isEmpty { return firstDetectionInterval }
        if hasCandidates { return candidateTrackingInterval }
        return stableTrackingInterval
    }

    private func startMotionMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            isDeviceStable = true
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            Task { @MainActor in
                self?.updateDeviceStability(from: motion)
            }
        }
    }

    private func updateDeviceStability(from motion: CMDeviceMotion) {
        let rotation = motion.rotationRate
        let acceleration = motion.userAcceleration
        let rotationMagnitude = sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z)
        let accelerationMagnitude = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z)
        let stable = rotationMagnitude < 0.95 && accelerationMagnitude < 0.18
        isDeviceStable = stable
        if !stable {
            resetDetectionProgress()
        }
    }

    private func isSubjectStable(recognized: [(String, CGRect)]) -> Bool {
        let rects = recognized
            .map(\.1)
            .filter { $0.width >= 18 && $0.height >= 8 }
            .sorted {
                if abs($0.midY - $1.midY) < 10 { return $0.midX < $1.midX }
                return $0.midY < $1.midY
            }
            .prefix(8)

        let currentRects = Array(rects)
        guard !currentRects.isEmpty else {
            lastSubjectRects = []
            stableSubjectFrames = 0
            return false
        }

        guard !lastSubjectRects.isEmpty else {
            lastSubjectRects = currentRects
            stableSubjectFrames = 0
            return true
        }

        let matchedCount = min(currentRects.count, lastSubjectRects.count)
        guard matchedCount > 0 else {
            lastSubjectRects = currentRects
            stableSubjectFrames = 0
            return false
        }

        let distances = (0..<matchedCount).map { index in
            hypot(currentRects[index].midX - lastSubjectRects[index].midX, currentRects[index].midY - lastSubjectRects[index].midY)
        }
        let averageDistance = distances.reduce(0, +) / CGFloat(matchedCount)
        let maxDistance = distances.max() ?? 0
        let countDelta = abs(currentRects.count - lastSubjectRects.count)
        let stable = averageDistance <= 30 && maxDistance <= 72 && countDelta <= 4

        lastSubjectRects = currentRects
        stableSubjectFrames = stable ? stableSubjectFrames + 1 : 0
        return stable
    }

    private func resetDetectionProgress() {
        progressWindow.reset()
        lastUsefulInputAt = Date.distantPast
        guard scanProgress != 0 else { return }
        withAnimation(.linear(duration: 0.06)) {
            scanProgress = 0
        }
    }

    func pruneStaleOverlays(homeCurrency: String, containerSize: CGSize) {
        let now = Date()
        let active = stabilizer.update(candidates: [], targetCurrency: homeCurrency, converter: converter, containerSize: containerSize)
        progressWindow.record(recognizedCount: 0, candidates: [], overlays: active, at: now)
        let hasRecentInput = now.timeIntervalSince(lastUsefulInputAt) < 1.1
        let nextProgress = hasRecentInput ? progressWindow.progress(currentProgress: scanProgress, at: now) : 0
        guard active.count != overlays.count || nextProgress != scanProgress else { return }
        withAnimation(.easeOut(duration: active.isEmpty ? 0.28 : 0.16)) {
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

private final class DetectionProgressWindow {
    private struct Sample {
        let date: Date
        let recognizedCount: Int
        let candidateCount: Int
        let bestCandidateConfidence: Double
        let bestHitCount: Int
        let hasStableOverlay: Bool
    }

    private var samples: [Sample] = []
    private let lifetime: TimeInterval = 0.9

    func record(recognizedCount: Int, candidates: [ParsedPriceCandidate], overlays: [PriceOverlayItem], at date: Date) {
        samples.append(
            Sample(
                date: date,
                recognizedCount: recognizedCount,
                candidateCount: candidates.count,
                bestCandidateConfidence: candidates.map(\.confidence).max() ?? 0,
                bestHitCount: overlays.map(\.hitCount).max() ?? 0,
                hasStableOverlay: overlays.contains { $0.confidence >= 0.90 || $0.hitCount >= 2 }
            )
        )
        prune(at: date)
    }

    func progress(currentProgress: CGFloat, at date: Date) -> CGFloat {
        prune(at: date)
        guard !samples.isEmpty else { return decayed(from: currentProgress, target: 0) }

        let target = targetProgress()
        if target >= currentProgress {
            return target
        }
        return decayed(from: currentProgress, target: target)
    }

    private func targetProgress() -> CGFloat {
        let recognized = samples.contains { $0.recognizedCount > 0 }
        let hasCandidate = samples.contains { $0.candidateCount > 0 }
        let bestConfidence = samples.map(\.bestCandidateConfidence).max() ?? 0
        let bestHitCount = samples.map(\.bestHitCount).max() ?? 0
        let stable = samples.contains { $0.hasStableOverlay }

        if stable || bestHitCount >= 3 || bestConfidence >= 0.95 { return 1.0 }
        if bestHitCount >= 2 || bestConfidence >= 0.90 { return 0.82 }
        if bestHitCount >= 1 { return 0.66 }
        if hasCandidate { return 0.48 }
        if recognized { return 0.22 }
        return 0
    }

    private func decayed(from currentProgress: CGFloat, target: CGFloat) -> CGFloat {
        max(target, currentProgress * 0.72)
    }

    private func prune(at date: Date) {
        samples.removeAll { date.timeIntervalSince($0.date) > lifetime }
    }

    func reset() {
        samples.removeAll()
    }
}
