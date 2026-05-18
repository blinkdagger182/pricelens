import SwiftUI

struct CurrencyPickerView: View {
    let title: String
    @Binding var selectedCode: String
    var dismissOnSelection = false
    var showsDoneButton = false
    var onSelect: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var currencies = Currency.supported
    @State private var searchText = ""

    var body: some View {
        ScrollViewReader { proxy in
            List(filteredCurrencies) { currency in
                Button {
                    selectedCode = currency.code
                    onSelect?(currency.code)
                    if dismissOnSelection {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 12) {
                        CurrencyFlagView(currency: currency)
                        VStack(alignment: .leading) {
                            Text(currency.code).foregroundStyle(.white)
                            Text(currency.name).font(.caption).foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        if selectedCode == currency.code { Image(systemName: "checkmark").foregroundStyle(AppTheme.accent) }
                    }
                }
                .id(currency.code)
                .listRowBackground(AppTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .task {
                await CurrencyRateService.shared.refreshIfNeeded()
                currencies = Currency.supported
                scrollToSelection(proxy)
            }
            .onAppear {
                scrollToSelection(proxy)
            }
            .onChange(of: searchText) { _, newValue in
                guard newValue.isEmpty else { return }
                scrollToSelection(proxy)
            }
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

    private func scrollToSelection(_ proxy: ScrollViewProxy) {
        let code = selectedCode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard filteredCurrencies.contains(where: { $0.code == code }) else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(code, anchor: .center)
            }
        }
    }
}
