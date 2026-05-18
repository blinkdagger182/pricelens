import SwiftUI

struct PriceOverlayCard: View {
    let item: PriceOverlayItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(CurrencyFormatter.string(item.amount, code: item.sourceCurrencyCode))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(AppTheme.accent)
                Spacer(minLength: 2)
            }
            Text(CurrencyFormatter.string(item.convertedAmount, code: item.targetCurrencyCode))
                .font(.title3.bold())
                .foregroundStyle(AppTheme.accent)
                .lineLimit(1)
            HStack {
                Text("\(item.sourceCurrencyCode) → \(item.targetCurrencyCode)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Circle().fill(item.confidence > 0.85 ? AppTheme.accent : .yellow).frame(width: 6, height: 6)
            }
        }
        .padding(12)
        .frame(width: 154, height: 76)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.accent.opacity(0.8), lineWidth: 1))
        .shadow(color: AppTheme.accent.opacity(0.30), radius: 14, y: 3)
    }
}

