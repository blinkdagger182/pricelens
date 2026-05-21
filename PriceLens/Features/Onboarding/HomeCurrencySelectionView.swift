import SwiftUI

struct HomeCurrencySelectionView: View {
    @Binding var selectedCode: String
    let onContinue: () -> Void
    @State private var currencies = Currency.supported

    var body: some View {
        CurrencySelectionContent(
            title: "Select Home Currency",
            subtitle: "Choose your home currency to see prices converted instantly.",
            selectedCode: $selectedCode,
            currencies: currencies,
            onContinue: onContinue
        )
        .task {
            await CurrencyRateService.shared.refreshIfNeeded()
            currencies = Currency.supported
        }
    }
}

struct CurrencySelectionContent: View {
    let title: String
    let subtitle: String
    @Binding var selectedCode: String
    let currencies: [Currency]
    let onContinue: () -> Void
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.title2.bold())
                Text(subtitle).font(.subheadline).foregroundStyle(AppTheme.textSecondary)
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredCurrencies) { currency in
                        Button { selectedCode = currency.code } label: {
                            HStack(spacing: 12) {
                                CurrencyFlagView(currency: currency)
                                Text(currency.code).font(.headline)
                                Text(currency.name).font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                                Spacer()
                                if selectedCode == currency.code {
                                    Image(systemName: "checkmark").foregroundStyle(AppTheme.accent)
                                }
                            }
                            .padding()
                            .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(selectedCode == currency.code ? AppTheme.accent : AppTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            searchField
            PrimaryButton(title: "Continue", action: onContinue)
        }
        .padding(22)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            TextField("Search currencies", text: $searchText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(AppTheme.textPrimary)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var filteredCurrencies: [Currency] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return currencies }
        return currencies.filter {
            $0.code.lowercased().contains(query)
                || $0.name.lowercased().contains(query)
                || $0.symbol.lowercased().contains(query)
        }
    }
}
