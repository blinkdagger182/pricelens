import SwiftUI
import UIKit

struct ScannerView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var history: ScanHistoryStore
    @StateObject private var viewModel = ScannerViewModel()
    @State private var showHistory = false
    @State private var showManual = false
    @State private var showSettings = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                scannerBackground(size: proxy.size)
                LinearGradient(colors: [.black.opacity(0.82), .clear], startPoint: .top, endPoint: .center).ignoresSafeArea()
                PriceOverlayLayer(items: viewModel.overlays, onTap: viewModel.tap)
                topBar
                VStack { Spacer(); ScannerControlsView(isFrozen: $viewModel.isFrozen, showHistory: { showHistory = true }, showManual: { showManual = true }) }
                #if DEBUG
                debugControls(size: proxy.size)
                #endif
            }
            .ignoresSafeArea()
            .sheet(item: $viewModel.selectedOverlay) { overlay in
                ScanResultDetailSheet(overlay: overlay) { history.add(viewModel.historyItem(from: overlay)) }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showHistory) { HistoryView() }
            .sheet(isPresented: $showManual) { ManualConverterView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
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
            .padding(.top, 58)
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
            Button("Use Sample Prices") {
                viewModel.process(recognized: OCRSnapshotService().debugSamples(), travelCurrency: settings.travelCurrencyCode, homeCurrency: settings.homeCurrencyCode, containerSize: size, force: true)
            }
            .font(.caption.bold())
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.accent, in: Capsule())
            .padding(.bottom, 122)
        }
    }
    #endif
}

