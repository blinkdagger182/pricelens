import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var history: ScanHistoryStore
    @Environment(\.dismiss) private var dismiss

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
                Section("Rates") {
                    row("Rate status", value: "Local fallback")
                    row("Updated", value: "Bundled V1")
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
        }
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(AppTheme.textSecondary)
        }
    }
}

