import SwiftUI

struct CurrencyPickerView: View {
    let title: String
    @Binding var selectedCode: String

    var body: some View {
        List(Currency.supported) { currency in
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
    }
}

