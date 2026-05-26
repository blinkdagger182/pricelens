import SwiftUI

struct ManualConverterView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ManualConverterViewModel()
    @State private var currencies = Currency.supported
    let initialTravelAmount: Decimal?

    init(initialTravelAmount: Decimal? = nil) {
        self.initialTravelAmount = initialTravelAmount
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let buttonSize = calculatorButtonSize(for: proxy.size)
                VStack(spacing: 16) {
                    converterPanel
                    keypad(buttonSize: buttonSize)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(AppTheme.background.ignoresSafeArea())
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                viewModel.configure(
                    sourceCode: settings.travelCurrencyCode,
                    targetCode: settings.homeCurrencyCode,
                    initialAmount: initialTravelAmount
                )
            }
            .task {
                await viewModel.refreshRatesIfNeeded()
                currencies = Currency.supported
            }
        }
    }

    private var converterPanel: some View {
        HStack(spacing: 10) {
            Button { viewModel.swapCurrencies() } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 36)
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                amountRow(
                    amount: displayNumber(viewModel.sourceAmount, focused: viewModel.activeField == .source),
                    code: $viewModel.sourceCode,
                    isFocused: viewModel.activeField == .source
                ) {
                    viewModel.setActiveField(.source)
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, AppTheme.accent, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.3)
                    .shadow(color: AppTheme.accent.opacity(0.65), radius: 8)
                    .padding(.horizontal, 14)

                amountRow(
                    amount: displayNumber(viewModel.targetAmount, focused: viewModel.activeField == .target),
                    code: $viewModel.targetCode,
                    isFocused: viewModel.activeField == .target
                ) {
                    viewModel.setActiveField(.target)
                }
            }
            .padding(.vertical, 18)
            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.accent, lineWidth: 1.2))
        }
    }

    private func amountRow(amount: String, code: Binding<String>, isFocused: Bool, activate: @escaping () -> Void) -> some View {
        Button(action: activate) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(amount)
                    .font(.system(size: amountFontSize(for: amount), weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(isFocused ? .white : .white.opacity(0.34))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Picker("", selection: code) {
                    ForEach(currencies) { currency in
                        Text("\(currency.flag == "¤" ? currency.code : currency.flag) \(currency.code)").tag(currency.code)
                    }
                }
                .pickerStyle(.menu)
                .tint(isFocused ? .white : .white.opacity(0.48))
                .frame(width: 72)
            }
            .padding(.horizontal, 16)
            .frame(height: 96)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func keypad(buttonSize: CGFloat) -> some View {
        Grid(horizontalSpacing: 13, verticalSpacing: 13) {
            GridRow {
                calculatorButton(.system("delete.left"), size: buttonSize) { viewModel.delete() }
                calculatorButton(.text("C"), size: buttonSize) { viewModel.clear() }
                calculatorButton(.text("%"), size: buttonSize) { viewModel.percent() }
                calculatorButton(.operation("÷"), size: buttonSize, isSelected: viewModel.pendingOperation == .divide) { viewModel.setOperation(.divide) }
            }
            GridRow {
                calculatorButton(.text("7"), size: buttonSize) { viewModel.append("7") }
                calculatorButton(.text("8"), size: buttonSize) { viewModel.append("8") }
                calculatorButton(.text("9"), size: buttonSize) { viewModel.append("9") }
                calculatorButton(.operation("×"), size: buttonSize, isSelected: viewModel.pendingOperation == .multiply) { viewModel.setOperation(.multiply) }
            }
            GridRow {
                calculatorButton(.text("4"), size: buttonSize) { viewModel.append("4") }
                calculatorButton(.text("5"), size: buttonSize) { viewModel.append("5") }
                calculatorButton(.text("6"), size: buttonSize) { viewModel.append("6") }
                calculatorButton(.operation("−"), size: buttonSize, isSelected: viewModel.pendingOperation == .subtract) { viewModel.setOperation(.subtract) }
            }
            GridRow {
                calculatorButton(.text("1"), size: buttonSize) { viewModel.append("1") }
                calculatorButton(.text("2"), size: buttonSize) { viewModel.append("2") }
                calculatorButton(.text("3"), size: buttonSize) { viewModel.append("3") }
                calculatorButton(.operation("+"), size: buttonSize, isSelected: viewModel.pendingOperation == .add) { viewModel.setOperation(.add) }
            }
            GridRow {
                calculatorButton(.text("+/−"), size: buttonSize) { viewModel.toggleSign() }
                calculatorButton(.text("0"), size: buttonSize) { viewModel.append("0") }
                calculatorButton(.text(","), size: buttonSize) { viewModel.append(".") }
                calculatorButton(.operation("="), size: buttonSize) { viewModel.equals() }
            }
        }
    }

    private func calculatorButton(_ content: CalculatorButtonContent, size: CGFloat, isSelected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            buttonLabel(content)
                .font(.system(size: fontSize(for: content), weight: .regular))
                .foregroundStyle(content.isOperation ? .white : .white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(content.isOperation ? AppTheme.accent : AppTheme.surfaceSecondary)
                )
                .overlay(
                    Circle()
                        .stroke(content.isOperation ? AppTheme.accent.opacity(0.95) : .white.opacity(0.16), lineWidth: 1)
                )
                .scaleEffect(isSelected ? 0.94 : 1)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func buttonLabel(_ content: CalculatorButtonContent) -> some View {
        switch content {
        case .text(let value), .operation(let value):
            Text(value)
        case .system(let name):
            Image(systemName: name)
        }
    }

    private func fontSize(for content: CalculatorButtonContent) -> CGFloat {
        switch content {
        case .text("+/−"):
            return 32
        case .text("C"), .text("%"):
            return 35
        case .operation:
            return 42
        case .system:
            return 30
        case .text:
            return 46
        }
    }

    private func calculatorButtonSize(for size: CGSize) -> CGFloat {
        let horizontalPadding: CGFloat = 36
        let buttonSpacing: CGFloat = 13
        let widthSize = (size.width - horizontalPadding - buttonSpacing * 3) / 4
        let heightSize = max(58, (size.height - 230) / 5.35)
        return min(92, max(64, min(widthSize, heightSize)))
    }

    private func displayNumber(_ amount: Decimal, focused: Bool) -> String {
        let number = NSDecimalNumber(decimal: amount)
        if abs(number.doubleValue) >= 1_000_000_000_000 {
            return scientificNumber(number)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = focused ? 6 : 2
        let formatted = formatter.string(from: number) ?? "0"
        return formatted.count > 16 ? scientificNumber(number) : formatted
    }

    private func scientificNumber(_ number: NSDecimalNumber) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .scientific
        formatter.maximumSignificantDigits = 7
        formatter.exponentSymbol = "e"
        formatter.decimalSeparator = ","
        return formatter.string(from: number) ?? "0"
    }

    private func amountFontSize(for value: String) -> CGFloat {
        switch value.count {
        case 0...7:
            return 58
        case 8...10:
            return 50
        case 11...13:
            return 42
        case 14...16:
            return 34
        default:
            return 30
        }
    }
}

private enum CalculatorButtonContent {
    case text(String)
    case system(String)
    case operation(String)

    var isOperation: Bool {
        if case .operation = self { return true }
        return false
    }
}
