import Foundation
import UIKit

@MainActor
final class AppVersionStore: ObservableObject {
    @Published private(set) var policy: AppVersionPolicy?
    @Published private(set) var requirement: AppUpdateRequirement = .none
    @Published private(set) var isChecking = false
    @Published private var dismissedOptionalVersion: String?

    private let client: AppVersionClient
    private let defaults: UserDefaults

    init(
        client: AppVersionClient = AppVersionClient(),
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.defaults = defaults
        dismissedOptionalVersion = defaults.string(forKey: AppStorageKeys.dismissedOptionalUpdateVersion)
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var shouldShowUpdate: Bool {
        guard let policy else { return false }

        switch requirement {
        case .required:
            return true
        case .optional:
            return dismissedOptionalVersion != policy.latestVersion
        case .none:
            return false
        }
    }

    var isRequiredUpdate: Bool {
        requirement == .required
    }

    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            let fetchedPolicy = try await client.fetchPolicy(currentVersion: currentVersion)
            policy = fetchedPolicy
            requirement = fetchedPolicy.requirement(for: currentVersion)
        } catch {
            requirement = .none
            print("Could not check app version policy: \(error.localizedDescription)")
        }
    }

    func dismissOptionalUpdate() {
        guard requirement == .optional, let policy else { return }
        defaults.set(policy.latestVersion, forKey: AppStorageKeys.dismissedOptionalUpdateVersion)
        dismissedOptionalVersion = policy.latestVersion
    }

    func openAppStore() {
        let fallbackURL = URL(string: "itms-apps://itunes.apple.com/search?term=Pricetag%20AI&entity=software")
        guard let url = policy?.appStoreURL ?? fallbackURL else { return }
        UIApplication.shared.open(url)
    }
}
