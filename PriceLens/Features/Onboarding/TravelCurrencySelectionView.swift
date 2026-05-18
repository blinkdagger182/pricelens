import SwiftUI

struct TravelCurrencySelectionView: View {
    @Binding var selectedCode: String
    let onContinue: () -> Void

    var body: some View {
        CurrencySelectionContent(
            title: "Select Travel Currency",
            subtitle: "Choose the currency of the country you're visiting.",
            selectedCode: $selectedCode,
            currencies: Currency.supported.filter { $0.code != "MYR" } + [Currency.find("MYR")],
            onContinue: onContinue
        )
    }
}

