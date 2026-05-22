import AVFoundation
import SwiftUI
import UIKit

struct ScannerView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var history: ScanHistoryStore
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
    @State private var isTorchOn = false

    private let bottomChromeHeight: CGFloat = 152
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
            .sheet(item: $viewModel.selectedOverlay) { overlay in
                ScanResultDetailSheet(overlay: overlay) { history.add(viewModel.historyItem(from: overlay)) }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showHistory) { HistoryView() }
            .sheet(isPresented: $showManual) { ManualConverterView() }
            .sheet(isPresented: $showSettings, onDismiss: refreshBlockingUIPause) { SettingsView() }
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
            .onChange(of: selectedCurrencyRole) { _, _ in refreshBlockingUIPause() }
            .onChange(of: fullPickerRole) { _, _ in refreshBlockingUIPause() }
            .onDisappear {
                setTorch(false)
            }
        }
    }

    private var cameraViewport: some View {
        GeometryReader { cameraProxy in
            let size = cameraProxy.size
            ZStack {
                scannerBackground(size: size)
                PriceOverlayLayer(detections: viewModel.detections, items: viewModel.overlays, onTap: viewModel.tap)
                topBar
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
                LiveScanProgressBar(progress: visibleScanProgress)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
            }
            .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
            .task(id: "\(Int(size.width))x\(Int(size.height))") {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
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
        ZStack {
            AppTheme.background
            ScannerControlsView(
                isFrozen: $viewModel.isFrozen,
                snap: startSnap,
                showHistory: { showHistory = true },
                showManual: { showManual = true }
            )
        }
    }

    private var visibleScanProgress: CGFloat {
        viewModel.scanProgress
    }

    private func scannerBackground(size: CGSize) -> some View {
        ZStack {
            DataScannerRepresentable(
                onRecognizedItems: { items in viewModel.process(recognized: items, travelCurrency: settings.travelCurrencyCode, homeCurrency: settings.homeCurrencyCode, containerSize: size) },
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
                    Text("Fallback rates").font(.caption2.bold()).foregroundStyle(.black).padding(.horizontal, 9).padding(.vertical, 5).background(AppTheme.accent, in: Capsule())
                }
                Spacer()
                Button { toggleTorch() } label: {
                    Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash")
                        .font(.headline)
                        .foregroundStyle(isTorchOn ? AppTheme.accent : .white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isTorchOn ? "Turn flash off" : "Turn flash on")
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

    private func swapCurrencies() {
        settings.swapCurrencies()
        viewModel.resetDetectionState()
    }

    private func toggleTorch() {
        setTorch(!isTorchOn)
    }

    private func setTorch(_ enabled: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            isTorchOn = false
            return
        }

        var didLock = false
        do {
            try device.lockForConfiguration()
            didLock = true
            if enabled {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            isTorchOn = enabled
        } catch {
            if didLock {
                device.unlockForConfiguration()
            }
            isTorchOn = false
        }
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
        let shouldPause = showSettings || selectedCurrencyRole != nil || fullPickerRole != nil
        if shouldPause, !isBlockingUIPauseActive {
            wasFrozenBeforeBlockingUI = viewModel.isFrozen
            isBlockingUIPauseActive = true
            viewModel.isFrozen = true
        } else if !shouldPause, isBlockingUIPauseActive {
            isBlockingUIPauseActive = false
            viewModel.isFrozen = wasFrozenBeforeBlockingUI
        }
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
        guard let capturedImage = await capturePhoto() else {
            viewModel.isFrozen = wasFrozenBeforeSnapPreview
            return
        }
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

    @MainActor
    private func resumeLiveDetectionAfterSnap() {
        viewModel.isFrozen = wasFrozenBeforeSnapPreview
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
        let parsed = prioritizer.sort(mappedCandidates, in: canvasSize)

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
                if candidate.confidence > result[index].confidence {
                    result[index] = candidate
                }
            } else {
                result.append(candidate)
            }
        }
        return result
    }

    private func snapshotCandidate(_ lhs: ParsedPriceCandidate, matches rhs: ParsedPriceCandidate) -> Bool {
        lhs.amount == rhs.amount
            && lhs.currencyCode == rhs.currencyCode
            && hypot(lhs.bounds.midX - rhs.bounds.midX, lhs.bounds.midY - rhs.bounds.midY) < 56
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
            .appendingPathComponent("PriceLens-Snap-\(UUID().uuidString)")
            .appendingPathExtension("png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private struct LiveScanProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(AppTheme.accent)
                    .frame(width: max(0, proxy.size.width * min(max(progress, 0), 1)))
                    .shadow(color: AppTheme.accent.opacity(progress > 0 ? 0.75 : 0), radius: 10, y: 1)
            }
            .opacity(progress > 0 ? 1 : 0.42)
            .animation(.easeOut(duration: 0.14), value: progress)
        }
        .frame(height: 7)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
