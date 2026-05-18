import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title).font(.headline).foregroundStyle(AppTheme.textPrimary)
            Text(message).font(.subheadline).foregroundStyle(AppTheme.textSecondary).multilineTextAlignment(.center)
        }
        .padding()
    }
}

