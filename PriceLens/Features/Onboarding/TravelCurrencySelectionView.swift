import SwiftUI

struct TravelCurrencySelectionView: View {
    @Binding var selectedCode: String
    let onContinue: () -> Void
    @State private var currencies = Currency.supported

    var body: some View {
        CurrencySelectionContent(
            title: "Select Travel Currency",
            subtitle: "Choose the currency of the country you're visiting.",
            selectedCode: $selectedCode,
            currencies: currencies.filter { $0.code != "MYR" } + [Currency.find("MYR")],
            onContinue: onContinue
        )
        .task {
            await CurrencyRateService.shared.refreshIfNeeded()
            currencies = Currency.supported
        }
    }
}
