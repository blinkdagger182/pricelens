import CoreMotion
import CoreGraphics
import Foundation
import os
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
    @Published var detections: [PriceDetectionItem] = []
    @Published var state: ScannerUXState = .loadingCamera
    @Published var selectedOverlay: PriceOverlayItem?
    @Published var isFrozen = false
    @Published var usingFallbackRates = true
    @Published var scanProgress: CGFloat = 0

    private let parser = PriceParser()
    private let prioritizer = PriceCandidatePrioritizer()
    private let stabilizer = OverlayStabilizer()
    private let converter = ConversionEngine()
    private let rateService = CurrencyRateService.shared
    private let haptics = HapticsService()
    private var lastProcess = Date.distantPast
    private var lastFoundCount = 0
    private var lastUsefulInputAt = Date.distantPast
    private var deferredCandidateTask: Task<Void, Never>?
    private var processingGeneration = 0
    private var lastPrimaryCandidateKey: String?
    private var lastPrimaryPublishAt = Date.distantPast
    private var lastPrimaryOverlayID: UUID?
    private var instabilityStartedAt: Date?
    private var overlayRevealTask: Task<Void, Never>?
    private var visibleOverlayIDs: [UUID] = []
    private let progressWindow = DetectionProgressWindow()
    private let motionManager = CMMotionManager()
    private var isDeviceStable = true
    private var lastSubjectRects: [CGRect] = []
    private var stableSubjectFrames = 0
    private let primaryRepublishInterval: TimeInterval = 0.32
    private let firstDetectionInterval: TimeInterval = 0.075
    private let candidateTrackingInterval: TimeInterval = 0.10
    private let stableTrackingInterval: TimeInterval = 0.20
    private let instabilityResetDelay: TimeInterval = 0.32

    init() {
        usingFallbackRates = rateService.isUsingFallbackRates
        startMotionMonitoring()
    }

    deinit {
        deferredCandidateTask?.cancel()
        overlayRevealTask?.cancel()
        motionManager.stopDeviceMotionUpdates()
    }

    func refreshRatesIfNeeded() async {
        await rateService.refreshIfNeeded()
        usingFallbackRates = rateService.isUsingFallbackRates
    }

    func process(recognized: [(String, CGRect)], travelCurrency: String, homeCurrency: String, containerSize: CGSize, force: Bool = false) {
        guard !isFrozen else { return }
        let now = Date()

        let fastCandidates = prioritizedCandidates(
            recognized.flatMap { parser.fastParseNumeric(text: $0.0, bounds: $0.1, selectedTravelCurrency: travelCurrency) },
            containerSize: containerSize
        )
        if isDeviceStable, !fastCandidates.isEmpty {
            updateDetections(with: fastCandidates, at: now)
            let publishedFastPrimary = publishPrimaryCandidateIfNeeded(
                fastCandidates.first,
                recognizedCount: recognized.count,
                homeCurrency: homeCurrency,
                containerSize: containerSize,
                at: now,
                force: force
            )
            LiveScanDiagnostics.logFastPath(
                recognizedCount: recognized.count,
                fastCandidateCount: fastCandidates.count,
                publishedPrimary: publishedFastPrimary
            )
        }

        let subjectStable = isSubjectStable(recognized: recognized)
        guard isDeviceStable, subjectStable else {
            LiveScanDiagnostics.logStabilityBlocked(deviceStable: isDeviceStable, subjectStable: subjectStable, fastCandidateCount: fastCandidates.count)
            noteInstability(at: now)
            return
        }
        instabilityStartedAt = nil

        let parseInputs = expandedReceiptContext(from: recognized)
        let fullCandidates = parseInputs.flatMap { parser.parse(text: $0.0, bounds: $0.1, selectedTravelCurrency: travelCurrency) }
        let candidates = prioritizedCandidates(mergedCandidates(fastCandidates + fullCandidates), containerSize: containerSize)
        updateDetections(with: candidates, at: now)
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

        let didPublishPrimary = publishPrimaryCandidateIfNeeded(
            candidates.first,
            recognizedCount: recognized.count,
            homeCurrency: homeCurrency,
            containerSize: containerSize,
            at: now,
            force: force
        )

        let throttle = processingInterval(hasCandidates: !candidates.isEmpty)
        guard force || now.timeIntervalSince(lastProcess) > throttle else { return }
        lastProcess = now

        processingGeneration += 1
        deferredCandidateTask?.cancel()
        let generation = processingGeneration
        let immediateCandidates = didPublishPrimary ? [] : Array(candidates.prefix(immediateCandidateCount(for: candidates)))
        let deferredCandidates = Array(candidates.dropFirst(didPublishPrimary ? 1 : immediateCandidates.count))

        if !immediateCandidates.isEmpty {
            publish(candidates: immediateCandidates, recognizedCount: recognized.count, homeCurrency: homeCurrency, containerSize: containerSize, at: now)
        }

        guard !deferredCandidates.isEmpty else { return }
        deferredCandidateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(70))
            guard let self, !Task.isCancelled, self.processingGeneration == generation, !self.isFrozen else { return }
            self.publish(
                candidates: deferredCandidates,
                recognizedCount: recognized.count,
                homeCurrency: homeCurrency,
                containerSize: containerSize,
                at: Date()
            )
        }
    }

    private func publishPrimaryCandidateIfNeeded(
        _ candidate: ParsedPriceCandidate?,
        recognizedCount: Int,
        homeCurrency: String,
        containerSize: CGSize,
        at date: Date,
        force: Bool
    ) -> Bool {
        guard let candidate else { return false }
        let key = primaryCandidateKey(for: candidate)
        guard force || key != lastPrimaryCandidateKey || date.timeIntervalSince(lastPrimaryPublishAt) >= primaryRepublishInterval else {
            return false
        }
        lastPrimaryCandidateKey = key
        lastPrimaryPublishAt = date
        publishImmediatePrimary(candidate, recognizedCount: recognizedCount, homeCurrency: homeCurrency, containerSize: containerSize, at: date)
        return true
    }

    private func publishImmediatePrimary(
        _ candidate: ParsedPriceCandidate,
        recognizedCount: Int,
        homeCurrency: String,
        containerSize: CGSize,
        at date: Date
    ) {
        let publishStart = Date()
        let convertedAmount = converter.convert(candidate.amount, from: candidate.currencyCode, to: homeCurrency)
        let overlayID = existingPrimaryOverlayID(for: candidate) ?? lastPrimaryOverlayID ?? UUID()
        let overlay = PriceOverlayItem(
            id: overlayID,
            originalText: candidate.originalText,
            amount: candidate.amount,
            sourceCurrencyCode: candidate.currencyCode,
            targetCurrencyCode: homeCurrency,
            convertedAmount: convertedAmount,
            bounds: candidate.bounds,
            displayPoint: CGPoint(x: candidate.bounds.midX, y: candidate.bounds.midY),
            confidence: candidate.confidence,
            lastSeenAt: date,
            hitCount: max(overlays.first(where: { $0.id == overlayID })?.hitCount ?? 0, 1)
        )

        lastPrimaryOverlayID = overlayID
        visibleOverlayIDs = [overlayID]
        progressWindow.record(recognizedCount: recognizedCount, candidates: [candidate], overlays: [overlay], at: date)

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            overlays = [overlay]
            state = .pricesDetected
            scanProgress = max(scanProgress, 0.82)
        }
        markConvertedDetections(for: [overlay])
        if lastFoundCount == 0 { haptics.success() }
        lastFoundCount = max(lastFoundCount, 1)

        _ = stabilizer.update(candidates: [candidate], targetCurrency: homeCurrency, converter: converter, containerSize: containerSize)
        LiveScanDiagnostics.logImmediatePrimary(duration: Date().timeIntervalSince(publishStart))
    }

    private func existingPrimaryOverlayID(for candidate: ParsedPriceCandidate) -> UUID? {
        overlays.first {
            $0.amount == candidate.amount
                && $0.sourceCurrencyCode == candidate.currencyCode
                && hypot($0.bounds.midX - candidate.bounds.midX, $0.bounds.midY - candidate.bounds.midY) < 92
        }?.id
    }

    private func publish(candidates: [ParsedPriceCandidate], recognizedCount: Int, homeCurrency: String, containerSize: CGSize, at date: Date) {
        let publishStart = Date()
        let nextOverlays = stabilizer.update(candidates: candidates, targetCurrency: homeCurrency, converter: converter, containerSize: containerSize)
        let visibleOverlays = queuedVisibleOverlays(from: nextOverlays)
        markConvertedDetections(for: visibleOverlays)
        let nextState: ScannerUXState = nextOverlays.isEmpty ? .noPriceFound : .pricesDetected
        progressWindow.record(recognizedCount: recognizedCount, candidates: candidates, overlays: visibleOverlays, at: date)
        let nextProgress = progressWindow.progress(currentProgress: scanProgress, at: date)
        guard visibleOverlays != overlays || nextState != state || nextProgress != scanProgress else {
            scheduleOverlayRevealIfNeeded(from: nextOverlays)
            return
        }
        let animation: Animation = overlays.isEmpty && !visibleOverlays.isEmpty
            ? .easeOut(duration: 0.08)
            : .easeOut(duration: 0.10)
        withAnimation(animation) {
            overlays = visibleOverlays
            state = nextState
            scanProgress = nextProgress
        }
        if overlays.count > lastFoundCount { haptics.success() }
        lastFoundCount = overlays.count
        scheduleOverlayRevealIfNeeded(from: nextOverlays)
        LiveScanDiagnostics.logPublish(candidateCount: candidates.count, overlayCount: visibleOverlays.count, duration: Date().timeIntervalSince(publishStart))
    }

    private func queuedVisibleOverlays(from nextOverlays: [PriceOverlayItem]) -> [PriceOverlayItem] {
        let sorted = sortedOverlaysForDisplay(nextOverlays)
        let activeIDs = Set(sorted.map(\.id))
        visibleOverlayIDs.removeAll { !activeIDs.contains($0) }

        if visibleOverlayIDs.isEmpty, let first = sorted.first {
            visibleOverlayIDs = [first.id]
        }

        let visibleSet = Set(visibleOverlayIDs)
        return sorted.filter { visibleSet.contains($0.id) }
    }

    private func scheduleOverlayRevealIfNeeded(from nextOverlays: [PriceOverlayItem]) {
        let sorted = sortedOverlaysForDisplay(nextOverlays)
        guard visibleOverlayIDs.count < min(sorted.count, 5), overlayRevealTask == nil else { return }
        overlayRevealTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(140))
                guard !Task.isCancelled else { return }
                let active = self.sortedOverlaysForDisplay(self.stabilizer.currentOverlays)
                let activeIDs = active.map(\.id)
                self.visibleOverlayIDs.removeAll { !activeIDs.contains($0) }
                guard let next = active.first(where: { !self.visibleOverlayIDs.contains($0.id) }) else {
                    self.overlayRevealTask = nil
                    return
                }
                self.visibleOverlayIDs.append(next.id)
                let visible = self.queuedVisibleOverlays(from: active)
                withAnimation(.easeOut(duration: 0.10)) {
                    self.overlays = visible
                }
                self.markConvertedDetections(for: visible)
                if self.visibleOverlayIDs.count >= min(active.count, 5) {
                    self.overlayRevealTask = nil
                    return
                }
            }
        }
    }

    private func sortedOverlaysForDisplay(_ overlays: [PriceOverlayItem]) -> [PriceOverlayItem] {
        overlays.sorted { lhs, rhs in
            if lhs.confidence == rhs.confidence { return lhs.hitCount > rhs.hitCount }
            return lhs.confidence > rhs.confidence
        }
    }

    private func updateDetections(with candidates: [ParsedPriceCandidate], at date: Date) {
        detections.removeAll { date.timeIntervalSince($0.lastSeenAt) > 0.9 }

        for candidate in candidates.prefix(5) {
            let id = detectionID(for: candidate)
            if let index = detections.firstIndex(where: { $0.id == id }) {
                detections[index].bounds = smoothedRect(from: detections[index].bounds, to: candidate.bounds)
                detections[index].confidence = max(detections[index].confidence, candidate.confidence)
                detections[index].lastSeenAt = date
            } else {
                detections.append(
                    PriceDetectionItem(
                        id: id,
                        bounds: candidate.bounds,
                        confidence: candidate.confidence,
                        firstSeenAt: date,
                        lastSeenAt: date,
                        hasConvertedOverlay: false
                    )
                )
            }
        }
        markConvertedDetections(for: overlays)
    }

    private func markConvertedDetections(for overlays: [PriceOverlayItem]) {
        for index in detections.indices {
            detections[index].hasConvertedOverlay = overlays.contains { overlay in
                hypot(overlay.bounds.midX - detections[index].bounds.midX, overlay.bounds.midY - detections[index].bounds.midY) < 58
            }
        }
    }

    private func detectionID(for candidate: ParsedPriceCandidate) -> String {
        let bucketX = Int((candidate.bounds.midX / 56).rounded())
        let bucketY = Int((candidate.bounds.midY / 40).rounded())
        return "\(candidate.currencyCode)-\(candidate.amount)-\(bucketX)-\(bucketY)"
    }

    private func primaryCandidateKey(for candidate: ParsedPriceCandidate) -> String {
        let bucketX = Int((candidate.bounds.midX / 40).rounded())
        let bucketY = Int((candidate.bounds.midY / 32).rounded())
        return "\(candidate.currencyCode)-\(candidate.amount)-\(bucketX)-\(bucketY)"
    }

    private func smoothedRect(from old: CGRect, to new: CGRect) -> CGRect {
        let alpha = 0.42
        return CGRect(
            x: old.origin.x + (new.origin.x - old.origin.x) * alpha,
            y: old.origin.y + (new.origin.y - old.origin.y) * alpha,
            width: old.width + (new.width - old.width) * alpha,
            height: old.height + (new.height - old.height) * alpha
        )
    }

    private func prioritizedCandidates(_ candidates: [ParsedPriceCandidate], containerSize: CGSize) -> [ParsedPriceCandidate] {
        prioritizer.sort(candidates, in: containerSize)
    }

    private func mergedCandidates(_ candidates: [ParsedPriceCandidate]) -> [ParsedPriceCandidate] {
        var result: [ParsedPriceCandidate] = []
        for candidate in candidates {
            if let index = result.firstIndex(where: { isSameCandidate($0, candidate) }) {
                if candidate.confidence > result[index].confidence {
                    result[index] = candidate
                }
            } else {
                result.append(candidate)
            }
        }
        return result
    }

    private func isSameCandidate(_ lhs: ParsedPriceCandidate, _ rhs: ParsedPriceCandidate) -> Bool {
        lhs.amount == rhs.amount
            && lhs.currencyCode == rhs.currencyCode
            && hypot(lhs.bounds.midX - rhs.bounds.midX, lhs.bounds.midY - rhs.bounds.midY) < 46
    }

    private func immediateCandidateCount(for candidates: [ParsedPriceCandidate]) -> Int {
        guard !candidates.isEmpty else { return 0 }
        return 1
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
        let stable = rotationMagnitude < 1.85 && accelerationMagnitude < 0.34
        isDeviceStable = stable
        if !stable { noteInstability(at: Date()) }
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
        let stable = averageDistance <= 46 && maxDistance <= 108 && countDelta <= 5

        lastSubjectRects = currentRects
        stableSubjectFrames = stable ? stableSubjectFrames + 1 : 0
        return stable
    }

    private func noteInstability(at date: Date) {
        if instabilityStartedAt == nil {
            instabilityStartedAt = date
        }
        guard let startedAt = instabilityStartedAt, date.timeIntervalSince(startedAt) >= instabilityResetDelay else {
            return
        }
        resetDetectionState()
    }

    private func resetDetectionState() {
        deferredCandidateTask?.cancel()
        overlayRevealTask?.cancel()
        processingGeneration += 1
        progressWindow.reset()
        lastUsefulInputAt = Date.distantPast
        lastPrimaryCandidateKey = nil
        lastPrimaryPublishAt = Date.distantPast
        lastPrimaryOverlayID = nil
        instabilityStartedAt = nil
        lastSubjectRects = []
        stableSubjectFrames = 0
        lastFoundCount = 0
        visibleOverlayIDs = []
        overlayRevealTask = nil
        withAnimation(.linear(duration: 0.06)) {
            scanProgress = 0
            detections = []
            overlays = []
            if state == .pricesDetected {
                state = .scanning
            }
        }
    }

    func pruneStaleOverlays(homeCurrency: String, containerSize: CGSize) {
        let now = Date()
        let active = stabilizer.update(candidates: [], targetCurrency: homeCurrency, converter: converter, containerSize: containerSize)
        let visibleActive = queuedVisibleOverlays(from: active)
        progressWindow.record(recognizedCount: 0, candidates: [], overlays: visibleActive, at: now)
        let hasRecentInput = now.timeIntervalSince(lastUsefulInputAt) < 1.1
        let nextProgress = hasRecentInput ? progressWindow.progress(currentProgress: scanProgress, at: now) : 0
        guard visibleActive != overlays || nextProgress != scanProgress else { return }
        withAnimation(.easeOut(duration: active.isEmpty ? 0.28 : 0.16)) {
            overlays = visibleActive
            detections.removeAll { now.timeIntervalSince($0.lastSeenAt) > 0.9 }
            markConvertedDetections(for: visibleActive)
            scanProgress = nextProgress
            if overlays.isEmpty, state == .pricesDetected {
                state = .scanning
            }
        }
        lastFoundCount = overlays.count
        scheduleOverlayRevealIfNeeded(from: active)
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

private enum LiveScanDiagnostics {
    #if DEBUG
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PriceLens", category: "LiveScan")

    static func logFastPath(recognizedCount: Int, fastCandidateCount: Int, publishedPrimary: Bool) {
        logger.debug("fastPath recognized=\(recognizedCount) candidates=\(fastCandidateCount) publishedPrimary=\(publishedPrimary)")
    }

    static func logStabilityBlocked(deviceStable: Bool, subjectStable: Bool, fastCandidateCount: Int) {
        logger.debug("stabilityBlocked device=\(deviceStable) subject=\(subjectStable) fastCandidates=\(fastCandidateCount)")
    }

    static func logPublish(candidateCount: Int, overlayCount: Int, duration: TimeInterval) {
        logger.debug("publish candidates=\(candidateCount) overlays=\(overlayCount) durationMs=\(Int(duration * 1000))")
    }

    static func logImmediatePrimary(duration: TimeInterval) {
        logger.debug("immediatePrimary durationMs=\(Int(duration * 1000))")
    }
    #else
    static func logFastPath(recognizedCount: Int, fastCandidateCount: Int, publishedPrimary: Bool) {}
    static func logStabilityBlocked(deviceStable: Bool, subjectStable: Bool, fastCandidateCount: Int) {}
    static func logPublish(candidateCount: Int, overlayCount: Int, duration: TimeInterval) {}
    static func logImmediatePrimary(duration: TimeInterval) {}
    #endif
}
