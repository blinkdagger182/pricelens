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
        Array(settings.favoriteCurrencies.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            arrow
                .padding(.leading, role == .home ? 28 : 0)
                .padding(.trailing, role == .travel ? 28 : 0)
                .frame(maxWidth: .infinity, alignment: role == .home ? .leading : .trailing)

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
                                Text(currency.flag)
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
            .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.accent.opacity(0.45), lineWidth: 1))
            .shadow(color: AppTheme.accent.opacity(0.16), radius: 18, y: 8)
        }
    }

    private var arrow: some View {
        Triangle()
            .fill(.black.opacity(0.86))
            .frame(width: 18, height: 10)
            .overlay(Triangle().stroke(AppTheme.accent.opacity(0.45), lineWidth: 1))
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
