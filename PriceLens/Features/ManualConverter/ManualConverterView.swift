import SwiftUI

struct ManualConverterView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var viewModel: ManualConverterViewModel
    @Environment(\.dismiss) private var dismiss

    init() {
        _viewModel = StateObject(wrappedValue: ManualConverterViewModel())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                conversionCard(title: "From", code: $viewModel.sourceCode, amount: viewModel.amountText, isAccent: false)
                Button { viewModel.swapCurrencies() } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.headline.bold())
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.accent, in: Circle())
                }
                conversionCard(title: "To", code: $viewModel.targetCode, amount: CurrencyFormatter.string(viewModel.converted, code: viewModel.targetCode), isAccent: true)
                Text(viewModel.rateText).font(.caption).foregroundStyle(AppTheme.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                keypad
                Spacer()
            }
            .padding()
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Manual Convert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } }
            .onAppear {
                viewModel.sourceCode = settings.travelCurrencyCode
                viewModel.targetCode = settings.homeCurrencyCode
            }
        }
    }

    private func conversionCard(title: String, code: Binding<String>, amount: String, isAccent: Bool) -> some View {
        GlassCard {
            HStack {
                Picker(title, selection: code) {
                    ForEach(Currency.supported) { currency in
                        Text("\(currency.flag) \(currency.code)").tag(currency.code)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(title).font(.caption).foregroundStyle(AppTheme.textSecondary)
                    Text(amount)
                        .font(.system(size: isAccent ? 34 : 28, weight: .bold))
                        .foregroundStyle(isAccent ? AppTheme.accent : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
        }
    }

    private var keypad: some View {
        let keys = ["1","2","3","4","5","6","7","8","9",".","0","delete.left"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(keys, id: \.self) { key in
                Button {
                    key == "delete.left" ? viewModel.delete() : viewModel.append(key)
                } label: {
                    Group {
                        if key == "delete.left" { Image(systemName: key) } else { Text(key) }
                    }
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

