import Combine
import Foundation

@MainActor
final class ManualConverterViewModel: ObservableObject {
    enum ActiveField {
        case source
        case target
    }

    enum Operation {
        case add
        case subtract
        case multiply
        case divide
    }

    @Published var sourceCode: String
    @Published var targetCode: String
    @Published var amountText: String = "0"
    @Published var activeField: ActiveField = .source
    @Published var pendingOperation: Operation?

    private var storedValue: Decimal?
    private var startsNewInput = false
    private let maximumInputDigits = 9

    private let converter = ConversionEngine()
    private let rateService = CurrencyRateService.shared

    init(sourceCode: String = "JPY", targetCode: String = "MYR") {
        self.sourceCode = sourceCode
        self.targetCode = targetCode
    }

    var activeAmount: Decimal {
        decimal(from: amountText)
    }

    var sourceAmount: Decimal {
        switch activeField {
        case .source:
            return activeAmount
        case .target:
            return converter.convert(activeAmount, from: targetCode, to: sourceCode)
        }
    }

    var targetAmount: Decimal {
        switch activeField {
        case .source:
            return converter.convert(activeAmount, from: sourceCode, to: targetCode)
        case .target:
            return activeAmount
        }
    }

    var amount: Decimal {
        sourceAmount
    }

    var converted: Decimal {
        targetAmount
    }

    var rateText: String {
        converter.rateDescription(from: sourceCode, to: targetCode)
    }

    func append(_ value: String) {
        if value != ".", digitCount(in: amountText) >= maximumInputDigits, !startsNewInput { return }
        if startsNewInput {
            amountText = value == "." ? "0." : value
            startsNewInput = false
            return
        }
        if value == "." && amountText.contains(".") { return }
        if amountText == "0" && value != "." {
            amountText = value
        } else {
            amountText += value
        }
    }

    func delete() {
        if startsNewInput {
            amountText = "0"
            startsNewInput = false
            return
        }
        if amountText.isEmpty { return }
        amountText.removeLast()
        if amountText.isEmpty { amountText = "0" }
    }

    func clear() {
        amountText = "0"
        storedValue = nil
        pendingOperation = nil
        startsNewInput = false
    }

    func toggleSign() {
        if amountText == "0" { return }
        if amountText.hasPrefix("-") {
            amountText.removeFirst()
        } else {
            amountText = "-\(amountText)"
        }
    }

    func percent() {
        amountText = inputString(from: activeAmount / 100)
        startsNewInput = true
    }

    func setOperation(_ operation: Operation) {
        if let pendingOperation, let storedValue, !startsNewInput {
            amountText = inputString(from: apply(pendingOperation, lhs: storedValue, rhs: activeAmount))
        }
        storedValue = activeAmount
        pendingOperation = operation
        startsNewInput = true
    }

    func equals() {
        guard let operation = pendingOperation, let storedValue else { return }
        amountText = inputString(from: apply(operation, lhs: storedValue, rhs: activeAmount))
        self.storedValue = nil
        pendingOperation = nil
        startsNewInput = true
    }

    func setActiveField(_ field: ActiveField) {
        guard field != activeField else { return }
        let nextAmount = field == .source ? sourceAmount : targetAmount
        activeField = field
        amountText = inputString(from: nextAmount)
        storedValue = nil
        pendingOperation = nil
        startsNewInput = true
    }

    func swapCurrencies() {
        swap(&sourceCode, &targetCode)
        activeField = activeField == .source ? .target : .source
    }

    func refreshRatesIfNeeded() async {
        await rateService.refreshIfNeeded()
        objectWillChange.send()
    }

    func configure(sourceCode: String, targetCode: String, initialAmount: Decimal?) {
        self.sourceCode = sourceCode
        self.targetCode = targetCode
        activeField = .source
        amountText = inputString(from: initialAmount ?? 0)
        storedValue = nil
        pendingOperation = nil
        startsNewInput = initialAmount != nil
    }

    private func apply(_ operation: Operation, lhs: Decimal, rhs: Decimal) -> Decimal {
        switch operation {
        case .add:
            return lhs + rhs
        case .subtract:
            return lhs - rhs
        case .multiply:
            return lhs * rhs
        case .divide:
            guard rhs != 0 else { return 0 }
            return lhs / rhs
        }
    }

    private func decimal(from text: String) -> Decimal {
        Decimal(string: text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func digitCount(in text: String) -> Int {
        text.filter(\.isNumber).count
    }

    private func inputString(from decimal: Decimal) -> String {
        let number = NSDecimalNumber(decimal: decimal)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.decimalSeparator = "."
        return formatter.string(from: number) ?? "0"
    }
}
