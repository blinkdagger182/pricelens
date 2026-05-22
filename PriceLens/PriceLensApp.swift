import SwiftUI

@main
struct PriceLensApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var history = ScanHistoryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(history)
                .preferredColorScheme(.dark)
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
