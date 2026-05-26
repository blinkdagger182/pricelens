import SwiftUI
import RevenueCatUI

struct PriceLensPaywallView: View {
    @EnvironmentObject private var subscription: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let offering = subscription.paywallOffering {
                PaywallView(offering: offering, displayCloseButton: true)
            } else {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(AppTheme.accent)
                    Text("Loading Pricetag AI Pro")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(detailText)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background.ignoresSafeArea())
                .task {
                    await subscription.refresh()
                }
            }
            closeButton
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.headline.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close paywall")
    }

    private var detailText: String {
        if let message = subscription.errorMessage {
            return message
        }
        return "Fetching the `\(SubscriptionStore.paywallOfferingIdentifier)` offering from RevenueCat."
    }
}
