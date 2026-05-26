import SwiftUI
import RevenueCat

@main
struct PriceLensApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var history = ScanHistoryStore()
    @StateObject private var subscription = SubscriptionStore()
    @StateObject private var appVersion = AppVersionStore()
    @StateObject private var usageLimits = UsageLimitStore()

    init() {
        SubscriptionStore.configureRevenueCat()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(history)
                .environmentObject(subscription)
                .environmentObject(appVersion)
                .environmentObject(usageLimits)
                .preferredColorScheme(.dark)
                .task {
                    subscription.start()
                    await appVersion.checkForUpdates()
                }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var appVersion: AppVersionStore

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                ScannerView()
            } else {
                OnboardingView()
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .overlay {
            if appVersion.shouldShowUpdate, let policy = appVersion.policy {
                AppUpdateSheet(
                    policy: policy,
                    requirement: appVersion.requirement,
                    currentVersion: appVersion.currentVersion,
                    onUpdate: appVersion.openAppStore,
                    onDismiss: appVersion.dismissOptionalUpdate
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: appVersion.shouldShowUpdate)
        .task {
            await settings.updateHomeCurrencyFromStorefrontIfNeeded()
        }
    }
}
