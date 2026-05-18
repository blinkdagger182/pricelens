import SwiftUI

struct CurrencyFlagView: View {
    let currency: Currency

    var body: some View {
        Group {
            if currency.flag == "¤" {
                Text(String(currency.code.prefix(2)))
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28, height: 22)
                    .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(AppTheme.accent.opacity(0.35), lineWidth: 1))
            } else {
                Text(currency.flag)
                    .font(.title3)
                    .frame(width: 28, height: 22)
            }
        }
        .accessibilityHidden(true)
    }
}

