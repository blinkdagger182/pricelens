import SwiftUI

struct HistoryRowView: View {
    let item: ScanHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            Text(Currency.find(item.sourceCurrencyCode).flag).font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(CurrencyFormatter.string(item.originalAmount, code: item.sourceCurrencyCode)).font(.headline).foregroundStyle(.white)
                Text("\(item.sourceCurrencyCode) → \(item.targetCurrencyCode)").font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.string(item.convertedAmount, code: item.targetCurrencyCode)).font(.headline).foregroundStyle(.white)
                Text(item.createdAt, style: .time).font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
    }
}

