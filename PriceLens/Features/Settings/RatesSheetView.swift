import SwiftUI

struct RatesSheetView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var rateStatus = CurrencyRateService.shared.statusSnapshot
    @State private var currencies = Currency.supported
    @State private var showPinLimitToast = false
    @State private var toastTask: Task<Void, Never>?

    private let converter = ConversionEngine()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        pinnedSection
                        topRatesSection
                        allRatesSection
                    }
                    .padding(18)
                }
                if showPinLimitToast {
                    VStack {
                        Spacer()
                        pinLimitToast
                            .padding(.horizontal, 18)
                            .padding(.bottom, 18)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .zIndex(10)
                }
            }
            .navigationTitle("Exchange Rates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search currency")
            .task {
                await CurrencyRateService.shared.refreshIfNeeded()
                rateStatus = CurrencyRateService.shared.statusSnapshot
                currencies = Currency.supported
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rates into \(settings.homeCurrencyCode)")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Text(rateStatus.isOfficial ? "Official" : "Fallback")
                    .font(.caption.bold())
                    .foregroundStyle(rateStatus.isOfficial ? .black : AppTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(rateStatus.isOfficial ? AppTheme.accent : AppTheme.surfaceSecondary, in: Capsule())
            }

            if let nextRefreshText {
                Text("Next refresh \(nextRefreshText)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }

    private var topRatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Most Popular")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 8) {
                ForEach(Array(topRateItems.enumerated()), id: \.element.id) { index, item in
                    LeaderboardRateRow(rank: index + 1, item: item, isPinned: isPinned(item.code)) {
                        togglePinnedRate(item.code)
                    }
                }
            }
        }
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pinned")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(pinnedItems.count)")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
            }

            if pinnedItems.isEmpty {
                Text("Pin rates you check often.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(pinnedItems) { item in
                            PinnedRateCard(item: item) {
                                togglePinnedRate(item.code)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var allRatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All Currencies")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            LazyVStack(spacing: 8) {
                ForEach(filteredItems) { item in
                    RateListRow(item: item, isPinned: isPinned(item.code)) {
                        togglePinnedRate(item.code)
                    }
                }
            }
        }
    }

    private var allItems: [RateDisplayItem] {
        currencies
            .filter { $0.code != settings.homeCurrencyCode }
            .map { currency in
                RateDisplayItem(
                    currency: currency,
                    homeCode: settings.homeCurrencyCode,
                    converted: converter.convert(1, from: currency.code, to: settings.homeCurrencyCode)
                )
            }
            .sorted { lhs, rhs in
                if isPinned(lhs.code) != isPinned(rhs.code) {
                    return isPinned(lhs.code)
                }
                return lhs.code < rhs.code
            }
    }

    private var topRateItems: [RateDisplayItem] {
        Self.popularCurrencyCodes.compactMap { code in
            allItems.first { $0.code == code && $0.code != settings.homeCurrencyCode }
        }
    }

    private var pinnedItems: [RateDisplayItem] {
        settings.favoriteCurrencyCodes.compactMap { code in
            allItems.first { $0.code == code && $0.code != settings.homeCurrencyCode }
        }
    }

    private var filteredItems: [RateDisplayItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allItems }
        return allItems.filter {
            $0.code.localizedCaseInsensitiveContains(trimmed)
                || $0.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var statusText: String {
        guard let updatedAt = rateStatus.updatedAt else { return "Using bundled fallback rates" }
        return "Updated \(Self.relativeFormatter.localizedString(for: updatedAt, relativeTo: Date()))"
    }

    private var nextRefreshText: String? {
        guard let nextUpdateAt = rateStatus.nextUpdateAt else { return nil }
        return Self.dateTimeFormatter.string(from: nextUpdateAt)
    }

    private func isPinned(_ code: String) -> Bool {
        settings.favoriteCurrencyCodes.contains(code)
    }

    private var pinLimitToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "pin.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
            Text("You can pin up to \(SettingsStore.maxFavoriteCurrencyCount) currencies.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.black.opacity(0.88), in: Capsule())
        .overlay(Capsule().stroke(AppTheme.accent.opacity(0.34), lineWidth: 1))
        .shadow(color: .black.opacity(0.38), radius: 14, y: 8)
    }

    private func togglePinnedRate(_ code: String) {
        guard settings.togglePinnedRate(code) else {
            showPinLimitMessage()
            return
        }
    }

    private func showPinLimitMessage() {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            showPinLimitToast = true
        }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showPinLimitToast = false
                }
            }
        }
    }

    private static let popularCurrencyCodes = ["USD", "EUR", "JPY", "GBP", "SGD"]

    private static let relativeFormatter = RelativeDateTimeFormatter()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct RateDisplayItem: Identifiable {
    let currency: Currency
    let homeCode: String
    let converted: Decimal

    var id: String { code }
    var code: String { currency.code }
    var name: String { currency.name }
    var flag: String { currency.flag }
    var formattedRate: String {
        "1 \(code) = \(CurrencyFormatter.string(converted, code: homeCode))"
    }
}

private struct LeaderboardRateRow: View {
    let rank: Int
    let item: RateDisplayItem
    let isPinned: Bool
    let togglePin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline.bold())
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
                .background(AppTheme.accent, in: Circle())

            Text(item.flag)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.code)
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(item.name)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Text(item.formattedRate)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            Spacer()
            PinButton(isPinned: isPinned, action: togglePin)
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }
}

private struct PinnedRateCard: View {
    let item: RateDisplayItem
    let unpin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.flag)
                    .font(.title2)
                Spacer()
                Button(action: unpin) {
                    Image(systemName: "pin.fill")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unpin \(item.code)")
            }
            Text(item.code)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(item.formattedRate)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 158, height: 118, alignment: .topLeading)
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.accent.opacity(0.36), lineWidth: 1))
    }
}

private struct RateListRow: View {
    let item: RateDisplayItem
    let isPinned: Bool
    let togglePin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(item.flag)
                .font(.title2)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(item.code)  \(item.name)")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(item.formattedRate)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            PinButton(isPinned: isPinned, action: togglePin)
        }
        .padding(12)
        .background(AppTheme.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PinButton: View {
    let isPinned: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.subheadline.bold())
                .foregroundStyle(isPinned ? AppTheme.accent : AppTheme.textSecondary)
                .frame(width: 36, height: 36)
                .background(AppTheme.surfaceSecondary, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPinned ? "Unpin rate" : "Pin rate")
    }
}
