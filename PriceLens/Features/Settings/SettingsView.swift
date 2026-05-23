import SwiftUI
import RevenueCatUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var history: ScanHistoryStore
    @EnvironmentObject private var subscription: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @State private var rateStatus = CurrencyRateService.shared.statusSnapshot
    @State private var showHowToUse = false
    @State private var showPaywall = false
    @State private var showCustomerCenter = false

    var body: some View {
        NavigationStack {
            List {
                Section("Currencies") {
                    NavigationLink { CurrencyPickerView(title: "Home Currency", selectedCode: $settings.homeCurrencyCode) } label: {
                        row("Home currency", value: settings.homeCurrencyCode)
                    }
                    NavigationLink { CurrencyPickerView(title: "Travel Currency", selectedCode: $settings.travelCurrencyCode) } label: {
                        row("Travel currency", value: settings.travelCurrencyCode)
                    }
                }
                Section("PriceLens Plus") {
                    row("Subscription", value: subscriptionStatusText)
                    Button {
                        showPaywall = true
                    } label: {
                        Label("View plans", systemImage: "crown")
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .disabled(subscription.isLoading)

                    Button {
                        Task {
                            await subscription.restorePurchases()
                        }
                    } label: {
                        Label(subscription.isPurchasing ? "Restoring..." : "Restore purchases", systemImage: "arrow.clockwise")
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .disabled(subscription.isPurchasing)

                    Button {
                        showCustomerCenter = true
                    } label: {
                        Label("Manage subscription", systemImage: "person.crop.circle")
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    if !subscription.hasConfiguredProducts {
                        Text("No RevenueCat products are configured yet. Add products, an entitlement, and a current offering in RevenueCat before selling subscriptions.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    if let errorMessage = subscription.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                Section("Rates") {
                    row("Rate status", value: rateStatus.isOfficial ? "PriceLens Official Rates" : "Local fallback")
                    row("Source", value: providerName)
                    row("Updated", value: updatedText)
                    if let nextUpdateText {
                        row("Next refresh", value: nextUpdateText)
                    }
                    if let fetchedText {
                        row("Cached", value: fetchedText)
                    }
                }
                Section("Guide") {
                    Button {
                        showHowToUse = true
                    } label: {
                        HStack {
                            Label("How to use", systemImage: "camera.viewfinder")
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                Section("Privacy") {
                    Text("PriceLens reads prices on your device where possible. Camera images are not saved unless you save a scan.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Section("Data") {
                    Button("Clear history", role: .destructive) { history.clear() }
                }
                Section("About") {
                    row("App version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showHowToUse) {
                HowToUseView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPaywall, onDismiss: {
                Task {
                    await subscription.refresh()
                }
            }) {
                PaywallView(displayCloseButton: true)
            }
            .sheet(isPresented: $showCustomerCenter, onDismiss: {
                Task {
                    await subscription.refresh()
                }
            }) {
                CustomerCenterView()
            }
            .task {
                await CurrencyRateService.shared.refreshIfNeeded()
                rateStatus = CurrencyRateService.shared.statusSnapshot
                subscription.start()
            }
        }
    }

    private var subscriptionStatusText: String {
        if subscription.isLoading {
            return "Checking..."
        }
        return subscription.isPro ? "Active" : "Not subscribed"
    }

    private var providerName: String {
        guard rateStatus.isOfficial else { return rateStatus.provider }
        if rateStatus.provider.lowercased().contains("exchangerate") {
            return "ExchangeRate-API data"
        }
        return rateStatus.provider
    }

    private var updatedText: String {
        guard let updatedAt = rateStatus.updatedAt else { return "Bundled fallback" }
        return Self.dateTimeFormatter.string(from: updatedAt)
    }

    private var nextUpdateText: String? {
        guard let nextUpdateAt = rateStatus.nextUpdateAt else { return nil }
        return Self.dateTimeFormatter.string(from: nextUpdateAt)
    }

    private var fetchedText: String? {
        guard let fetchedAt = rateStatus.fetchedAt else { return nil }
        return Self.dateTimeFormatter.string(from: fetchedAt)
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(AppTheme.textSecondary)
        }
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct HowToUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 18) {
                    OnboardingHeroView()
                        .padding(.top, 10)

                    VStack(spacing: 10) {
                        Text("How to use PriceLens")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("Point your camera at price tags, menus, or receipts. PriceLens reads prices on device, converts them, and keeps the result anchored near the original value.")
                            .font(.body)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("How to use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
