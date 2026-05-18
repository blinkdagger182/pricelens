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
            .sheet(item: $fullPickerRole) { role in
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
        }
    }

    private var cameraViewport: some View {
        GeometryReader { cameraProxy in
            let size = cameraProxy.size
            ZStack {
                scannerBackground(size: size)
                PriceOverlayLayer(items: viewModel.overlays, onTap: viewModel.tap)
                topBar
                if let selectedCurrencyRole {
                    Color.black.opacity(0.42)
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
        VStack(spacing: 8) {
            HStack {
                Button { toggleCurrencyPanel(.home) } label: {
                    CurrencyPill(code: settings.homeCurrencyCode)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("PriceLens").font(.headline.bold()).foregroundStyle(.white)
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
}
