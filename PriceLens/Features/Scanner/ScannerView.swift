import SwiftUI
import UIKit

struct ScannerView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var history: ScanHistoryStore
    @StateObject private var viewModel = ScannerViewModel()
    @State private var showHistory = false
    @State private var showManual = false
    @State private var showSettings = false
    #if DEBUG
    @State private var isDebugStreaming = false
    @State private var debugSampleTask: Task<Void, Never>?
    #endif

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
            .sheet(isPresented: $showSettings) { SettingsView() }
            #if DEBUG
            .onDisappear {
                stopDebugStream()
            }
            #endif
        }
    }

    private var cameraViewport: some View {
        GeometryReader { cameraProxy in
            let size = cameraProxy.size
            ZStack {
                scannerBackground(size: size)
                LinearGradient(colors: [.black.opacity(0.78), .clear, .black.opacity(0.18)], startPoint: .top, endPoint: .center)
                PriceOverlayLayer(items: viewModel.overlays, onTap: viewModel.tap)
                topBar
                #if DEBUG
                debugControls(size: size)
                #endif
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
            .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
            .task(id: "\(Int(size.width))x\(Int(size.height))") {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                    viewModel.pruneStaleOverlays(homeCurrency: settings.homeCurrencyCode, containerSize: size)
                }
            }
        }
    }

    private var bottomChrome: some View {
        ZStack {
            AppTheme.background
            ScannerControlsView(
                isFrozen: $viewModel.isFrozen,
                showHistory: { showHistory = true },
                showManual: { showManual = true }
            )
        }
    }

    private func scannerBackground(size: CGSize) -> some View {
        ZStack {
            DataScannerRepresentable(
                onRecognizedItems: { items in viewModel.process(recognized: items, travelCurrency: settings.travelCurrencyCode, homeCurrency: settings.homeCurrencyCode, containerSize: size) },
                onUnavailable: { viewModel.scannerUnavailable() },
                onReady: { viewModel.scannerBecameAvailable() }
            )
            if viewModel.state == .scannerUnavailable || viewModel.state == .permissionDenied {
                AppTheme.background
                ErrorStateView(title: "Live scanning isn't available on this device.", message: "Use manual conversion in Simulator or on devices without VisionKit scanning.", actionTitle: "Manual Convert") { showManual = true }
                    .padding()
            }
        }
    }

    private var topBar: some View {
        VStack {
            HStack {
                CurrencyPill(code: settings.homeCurrencyCode)
                Spacer()
                Text("PriceLens").font(.headline.bold()).foregroundStyle(.white)
                Spacer()
                CurrencyPill(code: settings.travelCurrencyCode)
            }
            .padding(.horizontal, 16)
            .padding(.top, 54)
            HStack {
                if viewModel.usingFallbackRates {
                    Text("Fallback rates").font(.caption2.bold()).foregroundStyle(.black).padding(.horizontal, 9).padding(.vertical, 5).background(AppTheme.accent, in: Capsule())
                }
                Spacer()
                Button { showSettings = true } label: { Image(systemName: "gearshape").font(.headline).foregroundStyle(.white) }
            }
            .padding(.horizontal, 18)
            Spacer()
        }
    }

    #if DEBUG
    private func debugControls(size: CGSize) -> some View {
        VStack {
            Spacer()
            Button(isDebugStreaming ? "Stop Sample Stream" : "Live Sample Prices") {
                isDebugStreaming ? stopDebugStream() : startDebugStream(size: size)
            }
            .font(.caption.bold())
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.accent, in: Capsule())
            .padding(.bottom, 18)
        }
    }

    private func startDebugStream(size: CGSize) {
        isDebugStreaming = true
        debugSampleTask?.cancel()
        debugSampleTask = Task {
            var frame = 0
            while !Task.isCancelled {
                let samples = OCRSnapshotService().debugSamples(frame: frame)
                await MainActor.run {
                    viewModel.process(
                        recognized: samples,
                        travelCurrency: settings.travelCurrencyCode,
                        homeCurrency: settings.homeCurrencyCode,
                        containerSize: size,
                        force: true
                    )
                }
                frame += 1
                try? await Task.sleep(for: .milliseconds(280))
            }
        }
    }

    private func stopDebugStream() {
        isDebugStreaming = false
        debugSampleTask?.cancel()
        debugSampleTask = nil
    }
    #endif
}
