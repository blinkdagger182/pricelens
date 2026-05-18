import SwiftUI

enum ScannerCurrencyRole: String, Identifiable {
    case home
    case travel

    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: "Home Currency"
        case .travel: "Travel Currency"
        }
    }
}

struct CurrencyAnchoredPanel: View {
    @EnvironmentObject private var settings: SettingsStore
    let role: ScannerCurrencyRole
    var showAllCurrencies: () -> Void
    var dismiss: () -> Void

    private var selectedCode: String {
        role == .home ? settings.homeCurrencyCode : settings.travelCurrencyCode
    }

    private var favorites: [Currency] {
        var codes = settings.favoriteCurrencyCodes.filter { $0 != selectedCode }
        codes.insert(selectedCode, at: 0)
        return Array(Currency.currencies(for: Array(codes.prefix(5))))
            .sorted { lhs, rhs in
                if lhs.code == selectedCode { return true }
                if rhs.code == selectedCode { return false }
                return lhs.code < rhs.code
            }
    }

    var body: some View {
        ZStack(alignment: role == .home ? .topLeading : .topTrailing) {
            Triangle()
                .fill(.black.opacity(0.90))
                .frame(width: 22, height: 12)
                .overlay(Triangle().stroke(AppTheme.accent.opacity(0.42), lineWidth: 1))
                .offset(x: role == .home ? 26 : -26, y: 0)
                .zIndex(2)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(role.title)
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(selectedCode)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.surfaceSecondary, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 8) {
                    ForEach(favorites) { currency in
                        Button {
                            select(currency.code)
                        } label: {
                            HStack(spacing: 10) {
                                CurrencyFlagView(currency: currency)
                                Text(currency.code)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(currency.name)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                                Spacer()
                                if currency.code == selectedCode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 38)
                            .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    showAllCurrencies()
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("All currencies")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .frame(width: 286)
            .background(.black.opacity(0.90), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.accent.opacity(0.45), lineWidth: 1))
            .shadow(color: AppTheme.accent.opacity(0.16), radius: 18, y: 8)
            .padding(.top, 10)
        }
    }

    private func select(_ code: String) {
        switch role {
        case .home:
            settings.selectHomeCurrency(code)
        case .travel:
            settings.selectTravelCurrency(code)
        }
        dismiss()
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
