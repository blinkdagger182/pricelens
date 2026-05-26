import AVFoundation
import SwiftUI
import UIKit
import RevenueCatUI

private enum SnapFlashMode: CaseIterable {
    case auto
    case on
    case off

    var next: SnapFlashMode {
        switch self {
        case .auto: return .on
        case .on: return .off
        case .off: return .auto
        }
    }

    var iconName: String {
        switch self {
        case .auto: return "bolt.badge.a.fill"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        }
    }

    var accessibilityName: String {
        switch self {
        case .auto: return "auto"
        case .on: return "on"
        case .off: return "off"
        }
    }

    var shortTitle: String {
        switch self {
        case .auto: return "Auto"
        case .on: return "On"
        case .off: return "Off"
        }
    }
}

struct ScannerView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var history: ScanHistoryStore
    @EnvironmentObject private var subscription: SubscriptionStore
    @EnvironmentObject private var usageLimits: UsageLimitStore
    @StateObject private var viewModel = ScannerViewModel()
    @State private var showHistory = false
    @State private var showManual = false
    @State private var showSettings = false
    @State private var selectedCurrencyRole: ScannerCurrencyRole?
    @State private var fullPickerRole: ScannerCurrencyRole?
    @State private var snapshotPreview: ScannerSnapshot?
    @State private var isProcessingSnap = false
    @State private var scannerPhotoCapture: (() async -> UIImage?)?
    @State private var cameraViewportSize: CGSize = .zero
    @State private var wasFrozenBeforeSnapPreview = false
    @State private var wasFrozenBeforeBlockingUI = false
    @State private var isBlockingUIPauseActive = false
    @State private var snapFlashMode: SnapFlashMode = .auto
    @State private var showUpgradePaywall = false
    @State private var showRatesSheet = false
    @State private var snapQuotaToastMessage: String?
    @State private var snapQuotaToastTask: Task<Void, Never>?
    @AppStorage(AppStorageKeys.hasSeenScanUpsell) private var hasSeenScanUpsell = false
    @State private var showScanUpsell = false

    private let bottomChromeHeight: CGFloat = 218
    private let cameraCornerRadius: CGFloat = 34

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                cameraViewport
                    .frame(height: max(420, proxy.size.height - bottomChromeHeight))
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                bottomChrome
                    .frame(height: bottomChromeHeight)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color.black.ignoresSafeArea())
            .overlay(alignment: .bottom) {
                if let snapQuotaToastMessage {
                    SnapQuotaToast(message: snapQuotaToastMessage)
                        .padding(.horizontal, 20)
                        .padding(.bottom, bottomChromeHeight + 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(80)
                }
            }
            .sheet(item: $viewModel.selectedOverlay, onDismiss: refreshBlockingUIPause) { overlay in
                ScanResultDetailSheet(overlay: overlay) { history.add(viewModel.historyItem(from: overlay)) }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showHistory) { HistoryView() }
            .sheet(isPresented: $showManual) {
                ManualConverterView(initialTravelAmount: latestScannedTravelAmount)
            }
            .sheet(isPresented: $showSettings, onDismiss: refreshBlockingUIPause) { SettingsView() }
            .sheet(isPresented: $showRatesSheet, onDismiss: refreshBlockingUIPause) {
                RatesSheetView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showScanUpsell, onDismiss: refreshBlockingUIPause) {
                ScanFeatureUpsellView(
                    onClose: {
                        hasSeenScanUpsell = true
                        showScanUpsell = false
                    },
                    onUpgrade: {
                        hasSeenScanUpsell = true
                        showScanUpsell = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            showUpgradePaywall = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showUpgradePaywall, onDismiss: {
                refreshBlockingUIPause()
                Task {
                    await subscription.refresh()
                }
            }) {
                PriceLensPaywallView()
            }
            .sheet(item: $snapshotPreview, onDismiss: resumeLiveDetectionAfterSnap) { snapshot in
                ScannerSnapshotPreview(snapshot: snapshot)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $fullPickerRole, onDismiss: refreshBlockingUIPause) { role in
                NavigationStack {
                    CurrencyPickerView(
                        title: role.title,
                        selectedCode: binding(for: role),
                        dismissOnSelection: true,
                        showsDoneButton: true
                    )
                }
            }
            .task {
                await viewModel.refreshRatesIfNeeded()
                await settings.updateTravelCurrencyFromCurrentLocationIfNeeded()
            }
            .onChange(of: showSettings) { _, _ in refreshBlockingUIPause() }
            .onChange(of: showRatesSheet) { _, _ in refreshBlockingUIPause() }
            .onChange(of: showScanUpsell) { _, _ in refreshBlockingUIPause() }
            .onChange(of: showUpgradePaywall) { _, _ in refreshBlockingUIPause() }
            .onChange(of: selectedCurrencyRole) { _, _ in refreshBlockingUIPause() }
            .onChange(of: fullPickerRole) { _, _ in refreshBlockingUIPause() }
            .onChange(of: viewModel.selectedOverlay) { _, _ in refreshBlockingUIPause() }
            .onChange(of: subscription.isPro) { _, isPro in
                if isPro {
                    showUpgradePaywall = false
                    viewModel.resetDetectionState()
                }
            }
            .onChange(of: settings.liveDetectionEnabled) { _, _ in
                viewModel.resetDetectionState()
            }
        }
    }

    private var cameraViewport: some View {
        GeometryReader { cameraProxy in
            let size = cameraProxy.size
            ZStack {
                scannerBackground(size: size)
                PriceOverlayLayer(detections: viewModel.detections, items: viewModel.overlays, onTap: presentOverlayDetail)
                topBar
                if viewModel.shouldShowSnapHint {
                    snapHint
                        .padding(.bottom, 26)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(5)
                }
                if isProcessingSnap {
                    SnapProcessingOverlay()
                        .zIndex(30)
                        .transition(.opacity)
                }
                if let selectedCurrencyRole {
                    Color.black.opacity(0.68)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                self.selectedCurrencyRole = nil
                            }
                        }
                        .transition(.opacity)
                        .zIndex(10)
                    currencyPanel(for: selectedCurrencyRole)
                        .padding(.top, 47)
                        .padding(.horizontal, 16)
                        .transition(.scale(scale: 0.94, anchor: selectedCurrencyRole == .home ? .topLeading : .topTrailing).combined(with: .opacity))
                        .zIndex(20)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cameraCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cameraCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cameraCornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.95), lineWidth: 3)
            )
            .overlay(alignment: .bottom) {
                LiveScanBorderProgress(progress: visibleScanProgress)
            }
            .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
            .task(id: "\(Int(size.width))x\(Int(size.height))") {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard isScannerPreviewActive else { continue }
                    viewModel.pruneStaleOverlays(homeCurrency: settings.homeCurrencyCode, containerSize: size)
                }
            }
            .onAppear {
                cameraViewportSize = size
            }
            .onChange(of: size) { _, newValue in
                cameraViewportSize = newValue
            }
        }
    }

    private var bottomChrome: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 14) {
                scannerActionRail
                    .padding(.top, 10)

            ScannerControlsView(
                isFrozen: $viewModel.isFrozen,
                snap: startSnap,
                showHistory: { showHistory = true },
                showManual: { showManual = true }
            )
            }
        }
    }

    private var visibleScanProgress: CGFloat {
        viewModel.scanProgress
    }

    private var latestScannedTravelAmount: Decimal? {
        guard let overlay = viewModel.overlays.max(by: { $0.lastSeenAt < $1.lastSeenAt }) else { return nil }
        if overlay.sourceCurrencyCode == settings.travelCurrencyCode {
            return overlay.amount
        }
        return ConversionEngine().convert(overlay.amount, from: overlay.sourceCurrencyCode, to: settings.travelCurrencyCode)
    }

    private var isScannerPreviewActive: Bool {
        !showHistory
            && !showManual
            && !showSettings
            && !showRatesSheet
            && !showScanUpsell
            && !showUpgradePaywall
            && snapshotPreview == nil
            && fullPickerRole == nil
            && selectedCurrencyRole == nil
            && viewModel.selectedOverlay == nil
            && settings.liveDetectionEnabled
            && usageLimits.canUseLiveScan(isPro: subscription.isPro)
    }

    private func scannerBackground(size: CGSize) -> some View {
        ZStack {
            DataScannerRepresentable(
                isScanningEnabled: isScannerPreviewActive,
                onRecognizedItems: { items in processLiveItems(items, containerSize: size) },
                onUnavailable: { viewModel.scannerUnavailable() },
                onReady: { viewModel.scannerBecameAvailable() },
                onCaptureReady: { capture in scannerPhotoCapture = capture }
            )
            if viewModel.state == .scannerUnavailable || viewModel.state == .permissionDenied {
                AppTheme.background
                ErrorStateView(title: "Live scanning isn't available on this device.", message: "Use manual conversion in Simulator or on devices without VisionKit scanning.", actionTitle: "Manual Convert") { showManual = true }
                    .padding()
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack {
                Button { toggleCurrencyPanel(.home) } label: {
                    CurrencyPill(code: settings.homeCurrencyCode)
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: swapCurrencies) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 46, height: 34)
                        .background(.black.opacity(0.42), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(AppTheme.accent.opacity(0.55), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap currencies")
                Spacer()
                Button { toggleCurrencyPanel(.travel) } label: {
                    CurrencyPill(code: settings.travelCurrencyCode)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            HStack {
                if viewModel.usingFallbackRates {
                    Button {
                        showRatesSheet = true
                    } label: {
                        Text("Fallback rates").font(.caption2.bold()).foregroundStyle(.black).padding(.horizontal, 9).padding(.vertical, 5).background(AppTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        showRatesSheet = true
                    } label: {
                        Text(viewModel.rateTrustLabel).font(.caption2.bold()).foregroundStyle(AppTheme.accent).padding(.horizontal, 9).padding(.vertical, 5).background(.black.opacity(0.42), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 18)
            Spacer()
        }
    }

    private var scannerActionRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                RailToggleButton(
                    title: "Scan",
                    subtitle: subscription.isPro ? (settings.liveDetectionEnabled ? "Enabled" : "Disabled") : "Pro",
                    icon: settings.liveDetectionEnabled && subscription.isPro ? "viewfinder.circle.fill" : "viewfinder",
                    isActive: settings.liveDetectionEnabled && subscription.isPro,
                    isLocked: !subscription.isPro,
                    action: toggleLiveDetection
                )

                RailToggleButton(
                    title: "Flash",
                    subtitle: snapFlashMode.shortTitle,
                    icon: snapFlashMode.iconName,
                    isActive: snapFlashMode != .off,
                    isLocked: false,
                    action: cycleSnapFlashMode
                )

                railDivider

                ForEach(conversionTemplates) { template in
                    ConversionTemplatePill(template: template) {
                        applyConversionTemplate(template)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 74)
    }

    private var railDivider: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(width: 1, height: 44)
            .padding(.horizontal, 3)
    }

    private var snapHint: some View {
        VStack {
            Spacer()
            Button(action: startSnap) {
                HStack(spacing: 8) {
                    Image(systemName: "viewfinder")
                    Text("Snap for all prices")
                }
                .font(.caption.bold())
                .foregroundStyle(.black)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(AppTheme.accent, in: Capsule())
                .shadow(color: AppTheme.accent.opacity(0.32), radius: 10)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func swapCurrencies() {
        settings.swapCurrencies()
        viewModel.resetDetectionState()
    }

    private func cycleSnapFlashMode() {
        snapFlashMode = snapFlashMode.next
    }

    private func toggleLiveDetection() {
        guard subscription.isPro else {
            if hasSeenScanUpsell {
                presentUsagePaywall()
            } else {
                showScanUpsell = true
            }
            return
        }
        settings.liveDetectionEnabled.toggle()
    }

    private var conversionTemplates: [ConversionTemplate] {
        let home = settings.homeCurrencyCode.uppercased()
        let travel = settings.travelCurrencyCode.uppercased()
        let popularTravelCodes = ["USD", "EUR", "GBP", "AUD", "SGD", "JPY", "MYR"]
        let pairs = [
            ConversionTemplate(source: travel, target: home),
            ConversionTemplate(source: home, target: travel),
            ConversionTemplate(source: travel, target: "USD"),
            ConversionTemplate(source: "USD", target: home)
        ] + popularTravelCodes.map {
            ConversionTemplate(source: $0, target: home)
        }

        var seen = Set<String>()
        return pairs.filter { template in
            guard template.source != template.target else { return false }
            return seen.insert(template.id).inserted
        }
    }

    private func applyConversionTemplate(_ template: ConversionTemplate) {
        settings.selectHomeCurrency(template.target)
        settings.selectTravelCurrency(template.source)
        viewModel.resetDetectionState()
    }

    private func processLiveItems(_ items: [(String, CGRect)], containerSize: CGSize) {
        guard settings.liveDetectionEnabled, usageLimits.canUseLiveScan(isPro: subscription.isPro) else {
            viewModel.resetDetectionStateIfNeeded()
            return
        }

        viewModel.process(
            recognized: items,
            travelCurrency: settings.travelCurrencyCode,
            homeCurrency: settings.homeCurrencyCode,
            containerSize: containerSize,
            maxPublishedOverlays: 5
        )
    }

    private func presentUsagePaywall() {
        guard !subscription.isPro else { return }
        showUpgradePaywall = true
    }

    private func currencyPanel(for role: ScannerCurrencyRole) -> some View {
        HStack {
            if role == .travel { Spacer() }
            CurrencyAnchoredPanel(
                role: role,
                showAllCurrencies: {
                    selectedCurrencyRole = nil
                    fullPickerRole = role
                },
                dismiss: {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        selectedCurrencyRole = nil
                    }
                }
            )
            if role == .home { Spacer() }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func toggleCurrencyPanel(_ role: ScannerCurrencyRole) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            selectedCurrencyRole = selectedCurrencyRole == role ? nil : role
        }
    }

    @MainActor
    private func refreshBlockingUIPause() {
        let shouldPause = showSettings || showRatesSheet || showScanUpsell || showUpgradePaywall || selectedCurrencyRole != nil || fullPickerRole != nil || viewModel.selectedOverlay != nil
        if shouldPause, !isBlockingUIPauseActive {
            wasFrozenBeforeBlockingUI = viewModel.isFrozen
            isBlockingUIPauseActive = true
            viewModel.isFrozen = true
        } else if !shouldPause, isBlockingUIPauseActive {
            isBlockingUIPauseActive = false
            viewModel.isFrozen = wasFrozenBeforeBlockingUI
        }
    }

    @MainActor
    private func presentOverlayDetail(_ overlay: PriceOverlayItem) {
        if !isBlockingUIPauseActive {
            wasFrozenBeforeBlockingUI = viewModel.isFrozen
            isBlockingUIPauseActive = true
        }
        viewModel.isFrozen = true
        viewModel.tap(overlay)
    }

    private func binding(for role: ScannerCurrencyRole) -> Binding<String> {
        Binding(
            get: {
                role == .home ? settings.homeCurrencyCode : settings.travelCurrencyCode
            },
            set: { code in
                switch role {
                case .home:
                    settings.selectHomeCurrency(code)
                case .travel:
                    settings.selectTravelCurrency(code)
                }
            }
        )
    }

    private func startSnap() {
        guard let scannerPhotoCapture else { return }
        guard usageLimits.canUseSnap(isPro: subscription.isPro) else {
            presentUsagePaywall()
            return
        }
        Task {
            await captureLiveSnap(scannerPhotoCapture)
        }
    }

    @MainActor
    private func captureLiveSnap(_ capturePhoto: @escaping () async -> UIImage?) async {
        isProcessingSnap = true
        wasFrozenBeforeSnapPreview = viewModel.isFrozen
        viewModel.isFrozen = true
        defer {
            isProcessingSnap = false
        }
        let shouldUseFlashAssist = snapFlashMode == .on
        if shouldUseFlashAssist {
            await setSnapFlashAssist(true)
            try? await Task.sleep(for: .milliseconds(120))
        }
        let capturedImage = await capturePhoto()
        if shouldUseFlashAssist {
            await setSnapFlashAssist(false)
        }
        guard let capturedImage else {
            viewModel.isFrozen = wasFrozenBeforeSnapPreview
            return
        }
        usageLimits.recordSnapIfNeeded(isPro: subscription.isPro)
        let canvasSize = cameraViewportSize.width > 0 && cameraViewportSize.height > 0 ? cameraViewportSize : capturedImage.size
        let snapItems = await stillImageSnapshotOverlays(for: capturedImage, canvasSize: canvasSize)
        let renderedImage = renderSnapshotImage(base: capturedImage, overlays: snapItems, canvasSize: canvasSize)
        snapshotPreview = ScannerSnapshot(
            baseImage: capturedImage,
            renderedImage: renderedImage,
            overlays: snapItems,
            canvasSize: canvasSize,
            shareURL: writeSnapshotForSharing(renderedImage)
        )
    }

    private func setSnapFlashAssist(_ enabled: Bool) async {
        await Task.detached(priority: .userInitiated) {
            guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
            var didLock = false
            do {
                try device.lockForConfiguration()
                didLock = true
                if enabled {
                    try device.setTorchModeOn(level: min(0.75, AVCaptureDevice.maxAvailableTorchLevel))
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                if didLock {
                    device.unlockForConfiguration()
                }
            }
        }.value
    }

    @MainActor
    private func resumeLiveDetectionAfterSnap() {
        viewModel.isFrozen = wasFrozenBeforeSnapPreview
        showSnapQuotaToastIfNeeded()
    }

    @MainActor
    private func showSnapQuotaToastIfNeeded() {
        guard !subscription.isPro, usageLimits.remainingSnaps <= 5 else { return }
        let remaining = usageLimits.remainingSnaps
        snapQuotaToastTask?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            snapQuotaToastMessage = remaining == 0 ? "No free snaps left today" : "\(remaining) free snaps left today"
        }
        snapQuotaToastTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.18)) {
                    snapQuotaToastMessage = nil
                }
            }
        }
    }

    @MainActor
    private func stillImageSnapshotOverlays(for image: UIImage, canvasSize: CGSize) async -> [SnapshotPriceOverlay] {
        let service = OCRSnapshotService()
        let parser = PriceParser()
        let prioritizer = PriceCandidatePrioritizer()
        let converter = ConversionEngine()
        let recognized = (try? await service.recognizedText(in: image)) ?? []
        let parseInputs = snapshotExpandedContext(from: recognized)
        let fastParsed = recognized.flatMap {
            parser.fastParseNumeric(text: $0.0, bounds: $0.1, selectedTravelCurrency: settings.travelCurrencyCode)
        }
        let fullParsed = parseInputs.flatMap {
            parser.parse(text: $0.0, bounds: $0.1, selectedTravelCurrency: settings.travelCurrencyCode)
        }
        let mappedCandidates = mergeSnapshotCandidates(fastParsed + fullParsed).map { candidate in
            ParsedPriceCandidate(
                originalText: candidate.originalText,
                amount: candidate.amount,
                currencyCode: candidate.currencyCode,
                confidence: candidate.confidence,
                bounds: mappedPhotoBoundsToViewport(candidate.bounds, imageSize: image.size, canvasSize: canvasSize)
            )
        }
        let parsed = prioritizer.sort(mergeSnapshotCandidates(mappedCandidates), in: canvasSize)

        return parsed.prefix(16).map { candidate in
            let convertedAmount = converter.convert(candidate.amount, from: candidate.currencyCode, to: settings.homeCurrencyCode)
            return SnapshotPriceOverlay(
                converted: CurrencyFormatter.string(convertedAmount, code: settings.homeCurrencyCode),
                bounds: candidate.bounds,
                overlay: PriceOverlayItem(
                    id: UUID(),
                    originalText: candidate.originalText,
                    amount: candidate.amount,
                    sourceCurrencyCode: candidate.currencyCode,
                    targetCurrencyCode: settings.homeCurrencyCode,
                    convertedAmount: convertedAmount,
                    bounds: candidate.bounds,
                    displayPoint: CGPoint(x: candidate.bounds.midX, y: candidate.bounds.midY),
                    confidence: candidate.confidence,
                    lastSeenAt: Date(),
                    hitCount: 1
                )
            )
        }
    }

    private func snapshotExpandedContext(from recognized: [(String, CGRect)]) -> [(String, CGRect)] {
        let cleaned = recognized.compactMap { text, rect -> (String, CGRect)? in
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return (value, rect)
        }
        guard cleaned.count > 1 else { return cleaned }

        let lines = snapshotGroupedLines(from: cleaned)
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
                let maxGap = max(first.1.height, second.1.height) * 3.2
                guard gap >= -10, gap <= maxGap else { return [] }
                return [
                    (first.0 + second.0, first.1.union(second.1)),
                    ("\(first.0) \(second.0)", first.1.union(second.1))
                ]
            }
        }

        return cleaned + adjacentPairs + combinedLines
    }

    private func snapshotGroupedLines(from items: [(String, CGRect)]) -> [[(String, CGRect)]] {
        let sorted = items.sorted {
            if abs($0.1.midY - $1.1.midY) < 10 { return $0.1.minX < $1.1.minX }
            return $0.1.midY < $1.1.midY
        }
        return sorted.reduce(into: [[(String, CGRect)]]()) { groups, item in
            if let index = groups.indices.last {
                let group = groups[index]
                let averageMidY = group.map(\.1.midY).reduce(0, +) / CGFloat(group.count)
                let averageHeight = group.map(\.1.height).reduce(0, +) / CGFloat(group.count)
                let tolerance = max(12, min(38, averageHeight * 0.86))
                if abs(item.1.midY - averageMidY) <= tolerance {
                    groups[index].append(item)
                    return
                }
            }
            groups.append([item])
        }
    }

    private func mergeSnapshotCandidates(_ candidates: [ParsedPriceCandidate]) -> [ParsedPriceCandidate] {
        var result: [ParsedPriceCandidate] = []
        for candidate in candidates {
            if let index = result.firstIndex(where: { snapshotCandidate($0, matches: candidate) }) {
                if snapshotCandidatePriority(candidate) > snapshotCandidatePriority(result[index]) {
                    result[index] = candidate
                }
            } else {
                result.append(candidate)
            }
        }
        return result
    }

    private func snapshotCandidate(_ lhs: ParsedPriceCandidate, matches rhs: ParsedPriceCandidate) -> Bool {
        guard lhs.amount == rhs.amount, lhs.currencyCode == rhs.currencyCode else { return false }
        let yDistance = abs(lhs.bounds.midY - rhs.bounds.midY)
        let sameLine = yDistance <= max(18, min(44, max(lhs.bounds.height, rhs.bounds.height) * 1.25))
        let intersection = lhs.bounds.intersection(rhs.bounds)
        let lhsArea = max(1, lhs.bounds.width * lhs.bounds.height)
        let rhsArea = max(1, rhs.bounds.width * rhs.bounds.height)
        let overlapRatio = intersection.isNull ? 0 : (intersection.width * intersection.height) / min(lhsArea, rhsArea)
        let horizontalGap = max(lhs.bounds.minX, rhs.bounds.minX) - min(lhs.bounds.maxX, rhs.bounds.maxX)
        let closeOnSameLine = sameLine && horizontalGap <= max(80, max(lhs.bounds.height, rhs.bounds.height) * 4.2)
        return overlapRatio > 0.15 || closeOnSameLine
    }

    private func snapshotCandidatePriority(_ candidate: ParsedPriceCandidate) -> CGFloat {
        let area = max(1, candidate.bounds.width * candidate.bounds.height)
        let compactnessPenalty = min(4_000, area * 0.08)
        return CGFloat(candidate.confidence * 1_000)
            + candidate.bounds.height * 80
            - compactnessPenalty
    }

    private func mappedPhotoBoundsToViewport(_ bounds: CGRect, imageSize: CGSize, canvasSize: CGSize) -> CGRect {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return bounds }
        let scale = max(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let displayedWidth = imageSize.width * scale
        let displayedHeight = imageSize.height * scale
        let cropX = max(0, (displayedWidth - canvasSize.width) / 2)
        let cropY = max(0, (displayedHeight - canvasSize.height) / 2)
        return CGRect(
            x: bounds.origin.x * scale - cropX,
            y: bounds.origin.y * scale - cropY,
            width: bounds.width * scale,
            height: bounds.height * scale
        )
    }

    @MainActor
    private func renderSnapshotImage(base image: UIImage, overlays: [SnapshotPriceOverlay], canvasSize: CGSize) -> UIImage {
        let renderSize = canvasSize.width > 0 && canvasSize.height > 0 ? canvasSize : image.size
        let content = SnapshotRenderedImage(image: image, overlays: overlays, canvasSize: renderSize)
            .frame(width: renderSize.width, height: renderSize.height)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: renderSize.width, height: renderSize.height)
        renderer.scale = image.scale
        return renderer.uiImage ?? image
    }

    private func writeSnapshotForSharing(_ image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PricetagAI-Snap-\(UUID().uuidString)")
            .appendingPathExtension("png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private struct LiveScanBorderProgress: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .bottomLeading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 4)
                Capsule()
                    .fill(AppTheme.accent)
                    .frame(width: max(0, proxy.size.width * clamped), height: 4)
                    .shadow(color: AppTheme.accent.opacity(progress > 0 ? 0.7 : 0), radius: 8, y: -1)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 1.5)
            .opacity(progress > 0 ? 1 : 0)
            .animation(.easeOut(duration: 0.14), value: progress)
        }
        .frame(height: 8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ConversionTemplate: Identifiable, Equatable {
    let source: String
    let target: String

    var id: String { "\(source)-\(target)" }
}

private struct RailToggleButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isActive: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isActive ? AppTheme.accent : AppTheme.textPrimary)
                        .frame(width: 34, height: 34)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 16, height: 16)
                            .background(AppTheme.accent, in: Circle())
                            .offset(x: 3, y: 3)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isActive ? AppTheme.accent : AppTheme.textSecondary)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [
                        AppTheme.surfaceSecondary.opacity(0.96),
                        Color.black.opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? AppTheme.accent.opacity(0.8) : AppTheme.border, lineWidth: isActive ? 1.4 : 1)
            )
            .shadow(color: isActive ? AppTheme.accent.opacity(0.22) : .clear, radius: 14, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private struct ConversionTemplatePill: View {
    let template: ConversionTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(flag(for: template.source))
                Text(template.source)
                    .foregroundStyle(AppTheme.textPrimary)
                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
                Text(template.target)
                    .foregroundStyle(AppTheme.accent)
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color.black.opacity(0.66), in: Capsule())
            .overlay(Capsule().strokeBorder(AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func flag(for code: String) -> String {
        Currency.find(code).flag
    }
}

private struct SnapQuotaToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "camera.viewfinder")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.accent)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.black.opacity(0.78), in: Capsule())
        .overlay(Capsule().strokeBorder(AppTheme.accent.opacity(0.42), lineWidth: 1))
        .shadow(color: AppTheme.accent.opacity(0.18), radius: 14, y: 6)
    }
}

private struct SnapProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppTheme.accent)
                    .scaleEffect(1.18)
                Text("Finding every price")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Running still-image OCR")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.36), lineWidth: 1)
            )
            .shadow(color: AppTheme.accent.opacity(0.22), radius: 18, y: 8)
        }
        .allowsHitTesting(true)
    }
}

private struct ScannerSnapshot: Identifiable {
    let id = UUID()
    let baseImage: UIImage
    let renderedImage: UIImage
    let overlays: [SnapshotPriceOverlay]
    let canvasSize: CGSize
    let shareURL: URL?
}

private struct SnapshotPriceOverlay: Identifiable {
    let id = UUID()
    let converted: String
    let bounds: CGRect
    let overlay: PriceOverlayItem
}

private struct ScanFeatureUpsellView: View {
    let onClose: () -> Void
    let onUpgrade: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        OnboardingHeroView()
                            .frame(height: 430)
                            .padding(.top, 18)

                        VStack(spacing: 12) {
                            Text("Unlock Live Scan")
                                .font(.system(size: 40, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)

                            Text("No snapping. No typing. Point your camera at menus, shelves, or receipts and Pricetag AI converts prices as they appear.")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, 22)

                        VStack(spacing: 10) {
                            ScanUpsellBenefit(icon: "viewfinder.circle.fill", title: "Auto-detect prices live", subtitle: "Converted cards appear over the camera view without taking a photo.")
                            ScanUpsellBenefit(icon: "bolt.fill", title: "Built for quick travel checks", subtitle: "Scan menus and shelf labels faster when you only need the price.")
                            ScanUpsellBenefit(icon: "infinity", title: "Unlimited Pro scanning", subtitle: "Live scan is included with Pricetag AI Pro.")
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 22)
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "Continue to Pricetag AI Pro", action: onUpgrade)
                    Text("Live Scan is a Pro feature. Snap conversion remains available on the free plan.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 18)
                .background(
                    LinearGradient(
                        colors: [AppTheme.background.opacity(0.1), AppTheme.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 12)
            .accessibilityLabel("Close scan tutorial")
        }
    }
}

private struct ScanUpsellBenefit: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.bold())
                .foregroundStyle(AppTheme.accent)
                .frame(width: 38, height: 38)
                .background(AppTheme.accent.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(AppTheme.accent.opacity(0.28), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

private struct SnapshotRenderedImage: View {
    let image: UIImage
    let overlays: [SnapshotPriceOverlay]
    let canvasSize: CGSize
    var onTap: ((SnapshotPriceOverlay) -> Void)?

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
            ForEach(overlays) { item in
                let frame = SnapshotReplacementLayout.frame(for: item.bounds, in: canvasSize)
                SnapshotReplacementText(item: item, frame: frame)
                    .frame(width: frame.width, height: frame.height)
                    .contentShape(RoundedRectangle(cornerRadius: max(5, frame.height * 0.16), style: .continuous))
                    .position(x: frame.midX, y: frame.midY)
                    .onTapGesture { onTap?(item) }
                    .zIndex(Double(item.bounds.minY))
            }
        }
        .clipped()
    }
}

private enum SnapshotReplacementLayout {
    static func frame(for bounds: CGRect, in canvasSize: CGSize) -> CGRect {
        let paddedWidth = max(bounds.width * 1.08, 44)
        let paddedHeight = max(bounds.height * 1.18, 18)
        var rect = CGRect(
            x: bounds.midX - paddedWidth / 2,
            y: bounds.midY - paddedHeight / 2,
            width: paddedWidth,
            height: paddedHeight
        )
        rect.origin.x = min(max(rect.origin.x, 10), max(10, canvasSize.width - rect.width - 10))
        rect.origin.y = min(max(rect.origin.y, 10), max(10, canvasSize.height - rect.height - 10))
        return rect
    }
}

private struct SnapshotReplacementText: View {
    let item: SnapshotPriceOverlay
    let frame: CGRect

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(5, frame.height * 0.16), style: .continuous)
                .fill(Color(red: 0.94, green: 0.91, blue: 0.82).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: max(5, frame.height * 0.16), style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.6)
                )
                .blur(radius: 0.2)

            Text(item.converted)
                .font(.system(size: min(max(frame.height * 0.72, 11), 46), weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.black.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.42)
                .shadow(color: .white.opacity(0.16), radius: 0.5, y: 0.5)
                .padding(.horizontal, max(2, frame.width * 0.035))
        }
    }
}

private struct ScannerSnapshotPreview: View {
    let snapshot: ScannerSnapshot
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var history: ScanHistoryStore
    @State private var didCopy = false
    @State private var selectedOverlay: PriceOverlayItem?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 18) {
                    SnapshotRenderedImage(
                        image: snapshot.baseImage,
                        overlays: snapshot.overlays,
                        canvasSize: snapshot.canvasSize,
                        onTap: { selectedOverlay = $0.overlay }
                    )
                        .aspectRatio(snapshot.canvasSize, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 18, y: 10)

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.image = snapshot.renderedImage
                            didCopy = true
                        } label: {
                            Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)

                        if let shareURL = snapshot.shareURL {
                            ShareLink(item: shareURL) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.black)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Snap")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedOverlay) { overlay in
                ScanResultDetailSheet(overlay: overlay) {
                    history.add(historyItem(from: overlay))
                }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func historyItem(from overlay: PriceOverlayItem) -> ScanHistoryItem {
        ScanHistoryItem(
            originalAmount: overlay.amount,
            originalText: overlay.originalText,
            sourceCurrencyCode: overlay.sourceCurrencyCode,
            convertedAmount: overlay.convertedAmount,
            targetCurrencyCode: overlay.targetCurrencyCode,
            rateDescription: ConversionEngine().rateDescription(from: overlay.sourceCurrencyCode, to: overlay.targetCurrencyCode),
            createdAt: Date(),
            note: "Snap"
        )
    }
}
