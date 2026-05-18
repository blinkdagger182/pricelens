import SwiftUI

struct CurrencyPickerView: View {
    let title: String
    @Binding var selectedCode: String
    @State private var currencies = Currency.supported
    @State private var searchText = ""

    var body: some View {
        List(filteredCurrencies) { currency in
            Button {
                selectedCode = currency.code
            } label: {
                HStack {
                    Text(currency.flag)
                    VStack(alignment: .leading) {
                        Text(currency.code).foregroundStyle(.white)
                        Text(currency.name).font(.caption).foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if selectedCode == currency.code { Image(systemName: "checkmark").foregroundStyle(AppTheme.accent) }
                }
            }
            .listRowBackground(AppTheme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle(title)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .task {
            await CurrencyRateService.shared.refreshIfNeeded()
            currencies = Currency.supported
        }
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
