import SwiftUI
import RevenueCatUI

struct PriceLensPaywallView: View {
    @EnvironmentObject private var subscription: SubscriptionStore

    var body: some View {
        Group {
            if let offering = subscription.paywallOffering {
                PaywallView(offering: offering, displayCloseButton: true)
            } else {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(AppTheme.accent)
                    Text("Loading PriceLens Pro")
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
        }
    }

    private var detailText: String {
        if let message = subscription.errorMessage {
            return message
        }
        return "Fetching the `\(SubscriptionStore.paywallOfferingIdentifier)` offering from RevenueCat."
    }
}
