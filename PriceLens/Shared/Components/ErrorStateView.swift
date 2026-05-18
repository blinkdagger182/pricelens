import SwiftUI

struct ErrorStateView: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Text(title).font(.title3.bold())
            Text(message).font(.subheadline).foregroundStyle(AppTheme.textSecondary).multilineTextAlignment(.center)
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
            }
        }
        .padding(24)
    }
}

