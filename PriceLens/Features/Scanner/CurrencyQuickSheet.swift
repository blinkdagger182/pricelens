import SwiftUI

enum ScannerCurrencyRole: String, Identifiable {
    case home
    case travel

    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: "Home Currency"
        case .travel: "Travel Currency"
        }
    }
}

struct CurrencyQuickSheet: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    let role: ScannerCurrencyRole

    private var selectedCode: String {
        role == .home ? settings.homeCurrencyCode : settings.travelCurrencyCode
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Favorites") {
                    ForEach(settings.favoriteCurrencies) { currency in
                        Button {
                            select(currency.code)
                        } label: {
                            currencyRow(currency)
                        }
                        .listRowBackground(AppTheme.surface)
                    }
                }

                Section {
                    NavigationLink {
                        CurrencyPickerView(title: role.title, selectedCode: binding)
                    } label: {
                        Label("All currencies", systemImage: "magnifyingglass")
                    }
                    .listRowBackground(AppTheme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(role.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var binding: Binding<String> {
        Binding(
            get: { selectedCode },
            set: { select($0, dismissAfterSelection: false) }
        )
    }

    private func select(_ code: String, dismissAfterSelection: Bool = true) {
        switch role {
        case .home:
            settings.selectHomeCurrency(code)
        case .travel:
            settings.selectTravelCurrency(code)
        }
        if dismissAfterSelection {
            dismiss()
        }
    }

    private func currencyRow(_ currency: Currency) -> some View {
        HStack(spacing: 12) {
            Text(currency.flag)
            VStack(alignment: .leading, spacing: 3) {
                Text(currency.code).font(.headline).foregroundStyle(.white)
                Text(currency.name).font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if currency.code == selectedCode {
                Image(systemName: "checkmark").foregroundStyle(AppTheme.accent)
            }
        }
    }
}

