import Foundation
import RevenueCat

@MainActor
final class SubscriptionStore: ObservableObject {
    static let entitlementIdentifier = "pro"
    static let paywallOfferingIdentifier = "PriceLens Pro Weekly"

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private static let apiKey = "appl_NmzRajJULTaLIRFmgtfOeuhBHWW"
    private var customerInfoTask: Task<Void, Never>?

    var isPro: Bool {
        customerInfo?.entitlements[Self.entitlementIdentifier]?.isActive == true
    }

    var currentOffering: Offering? {
        offerings?.current
    }

    var paywallOffering: Offering? {
        offerings?[Self.paywallOfferingIdentifier] ?? offerings?.current
    }

    var availableOfferingIdentifiers: [String] {
        offerings?.all.keys.sorted() ?? []
    }

    var hasConfiguredProducts: Bool {
        paywallOffering?.availablePackages.isEmpty == false
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
            if paywallOffering == nil {
                let identifiers = availableOfferingIdentifiers.joined(separator: ", ")
                errorMessage = identifiers.isEmpty
                    ? "RevenueCat returned no offerings. Check that `PriceLens Pro Weekly` is configured and published."
                    : "RevenueCat did not return `PriceLens Pro Weekly`. Available offerings: \(identifiers)."
            }
        } catch {
            if errorMessage == nil {
                errorMessage = "Could not load RevenueCat offering `PriceLens Pro Weekly`. \(error.localizedDescription)"
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
