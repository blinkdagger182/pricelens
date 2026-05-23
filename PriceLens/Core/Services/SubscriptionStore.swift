import Foundation
import RevenueCat

@MainActor
final class SubscriptionStore: ObservableObject {
    static let entitlementIdentifier = "pro"

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private static let apiKey = "test_laOogpgavRqNpPSfezGtTNUNUIm"
    private var customerInfoTask: Task<Void, Never>?

    var isPro: Bool {
        customerInfo?.entitlements[Self.entitlementIdentifier]?.isActive == true
    }

    var currentOffering: Offering? {
        offerings?.current
    }

    var hasConfiguredProducts: Bool {
        currentOffering?.availablePackages.isEmpty == false
    }

    static func configureRevenueCat() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: apiKey)
    }

    func start() {
        guard customerInfoTask == nil else { return }
        customerInfoTask = Task { [weak self] in
            guard let self else { return }
            for await latestInfo in Purchases.shared.customerInfoStream {
                self.customerInfo = latestInfo
            }
        }

        Task {
            await refresh()
        }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            customerInfo = try await Purchases.shared.customerInfo()
        } catch {
            errorMessage = "Could not load subscription status. \(error.localizedDescription)"
        }

        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            if errorMessage == nil {
                errorMessage = "No RevenueCat offering is available yet. Configure products and an offering in RevenueCat."
            }
        }
    }

    func purchase(_ package: Package) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let (_, info, userCancelled) = try await Purchases.shared.purchase(package: package)
            guard !userCancelled else { return }
            customerInfo = info
        } catch {
            errorMessage = "Purchase failed. \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            customerInfo = try await Purchases.shared.restorePurchases()
        } catch {
            errorMessage = "Restore failed. \(error.localizedDescription)"
        }
    }

    deinit {
        customerInfoTask?.cancel()
    }
}
