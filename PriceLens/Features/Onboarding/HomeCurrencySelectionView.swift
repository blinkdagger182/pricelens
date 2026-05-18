import SwiftUI

struct HomeCurrencySelectionView: View {
    @Binding var selectedCode: String
    let onContinue: () -> Void

    var body: some View {
        CurrencySelectionContent(
            title: "Select Home Currency",
            subtitle: "Choose your home currency to see prices converted instantly.",
            selectedCode: $selectedCode,
            currencies: Currency.supported,
            onContinue: onContinue
        )
    }
}

struct CurrencySelectionContent: View {
    let title: String
    let subtitle: String
    @Binding var selectedCode: String
    let currencies: [Currency]
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.title2.bold())
                Text(subtitle).font(.subheadline).foregroundStyle(AppTheme.textSecondary)
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(currencies) { currency in
                        Button { selectedCode = currency.code } label: {
                            HStack(spacing: 12) {
                                Text(currency.flag).font(.title3)
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
            PrimaryButton(title: "Continue", action: onContinue)
        }
        .padding(22)
    }
}

