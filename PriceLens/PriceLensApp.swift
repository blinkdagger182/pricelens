import SwiftUI
import RevenueCat

@main
struct PriceLensApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var history = ScanHistoryStore()
    @StateObject private var subscription = SubscriptionStore()

    init() {
        SubscriptionStore.configureRevenueCat()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(history)
                .environmentObject(subscription)
                .preferredColorScheme(.dark)
                .task {
                    subscription.start()
                }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                ScannerView()
            } else {
                OnboardingView()
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .task {
            await settings.updateHomeCurrencyFromStorefrontIfNeeded()
        }
    }
}
