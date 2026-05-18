import Combine
import Foundation

@MainActor
final class ManualConverterViewModel: ObservableObject {
    @Published var sourceCode: String
    @Published var targetCode: String
    @Published var amountText: String = "1200"

    private let converter = ConversionEngine()

    init(sourceCode: String = "JPY", targetCode: String = "MYR") {
        self.sourceCode = sourceCode
        self.targetCode = targetCode
    }

    var amount: Decimal {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    var converted: Decimal {
        converter.convert(amount, from: sourceCode, to: targetCode)
    }

    var rateText: String {
        converter.rateDescription(from: sourceCode, to: targetCode)
    }

    func append(_ value: String) {
        if value == "." && amountText.contains(".") { return }
        if amountText == "0" { amountText = value } else { amountText += value }
    }

    func delete() {
        if amountText.isEmpty { return }
        amountText.removeLast()
        if amountText.isEmpty { amountText = "0" }
    }

    func swapCurrencies() {
        swap(&sourceCode, &targetCode)
    }
}

