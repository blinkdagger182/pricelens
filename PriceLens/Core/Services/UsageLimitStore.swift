import Foundation

@MainActor
final class UsageLimitStore: ObservableObject {
    static let dailyFreeSnaps = 10

    @Published private(set) var snapCount: Int

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        Self.resetIfNeeded(defaults: defaults, calendar: calendar)
        snapCount = defaults.integer(forKey: AppStorageKeys.dailySnapCount)
    }

    var remainingSnaps: Int {
        max(0, Self.dailyFreeSnaps - snapCount)
    }

    func canUseLiveScan(isPro: Bool) -> Bool {
        isPro
    }

    func canUseSnap(isPro: Bool) -> Bool {
        refreshDayIfNeeded()
        return isPro || remainingSnaps > 0
    }

    func recordSnapIfNeeded(isPro: Bool) {
        guard !isPro else { return }
        refreshDayIfNeeded()
        guard snapCount < Self.dailyFreeSnaps else { return }
        snapCount += 1
        defaults.set(snapCount, forKey: AppStorageKeys.dailySnapCount)
    }

    func refreshDayIfNeeded() {
        let previousKey = defaults.string(forKey: AppStorageKeys.dailyUsageDateKey)
        let todayKey = Self.dayKey(for: Date(), calendar: calendar)
        guard previousKey != todayKey else { return }

        defaults.set(todayKey, forKey: AppStorageKeys.dailyUsageDateKey)
        defaults.set(0, forKey: AppStorageKeys.dailySnapCount)
        snapCount = 0
    }

    private static func resetIfNeeded(defaults: UserDefaults, calendar: Calendar) {
        let todayKey = dayKey(for: Date(), calendar: calendar)
        guard defaults.string(forKey: AppStorageKeys.dailyUsageDateKey) != todayKey else { return }
        defaults.set(todayKey, forKey: AppStorageKeys.dailyUsageDateKey)
        defaults.set(0, forKey: AppStorageKeys.dailySnapCount)
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
