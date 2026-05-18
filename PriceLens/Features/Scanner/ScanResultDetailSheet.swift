import SwiftUI

struct ScanResultDetailSheet: View {
    let overlay: PriceOverlayItem
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var didSave = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule().fill(AppTheme.accent).frame(width: 42, height: 5).frame(maxWidth: .infinity)
            Text("Detected price").font(.headline).foregroundStyle(AppTheme.textSecondary)
            Text(CurrencyFormatter.string(overlay.amount, code: overlay.sourceCurrencyCode)).font(.largeTitle.bold())
            Divider().overlay(AppTheme.border)
            Text("Converted to \(overlay.targetCurrencyCode)").font(.subheadline).foregroundStyle(AppTheme.textSecondary)
            Text(CurrencyFormatter.string(overlay.convertedAmount, code: overlay.targetCurrencyCode)).font(.system(size: 42, weight: .bold)).foregroundStyle(AppTheme.accent)
            Text("\(overlay.sourceCurrencyCode) → \(overlay.targetCurrencyCode) • Updated just now").font(.caption).foregroundStyle(AppTheme.textSecondary)
            Spacer()
            HStack {
                PrimaryButton(title: didSave ? "Saved" : "Save") {
                    onSave()
                    didSave = true
                }
                ShareLink(item: "\(CurrencyFormatter.string(overlay.amount, code: overlay.sourceCurrencyCode)) = \(CurrencyFormatter.string(overlay.convertedAmount, code: overlay.targetCurrencyCode))") {
                    Text("Share").font(.headline).foregroundStyle(AppTheme.accent).frame(width: 96, height: 54).background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            Button("Copy conversion") {
                UIPasteboard.general.string = "\(CurrencyFormatter.string(overlay.amount, code: overlay.sourceCurrencyCode)) = \(CurrencyFormatter.string(overlay.convertedAmount, code: overlay.targetCurrencyCode))"
            }
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(AppTheme.background)
    }
}

