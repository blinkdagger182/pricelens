import SwiftUI

struct CurrencyPill: View {
    let code: String

    var body: some View {
        Text(code)
            .font(.caption.bold())
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.55), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.accent.opacity(0.9), lineWidth: 1))
    }
}

