import SwiftUI

struct OnboardingConversionCard: View {
    var scale: CGFloat = 1
    var emphasis: CGFloat = 1
    var conversion: OnboardingDemoConversion = .fallback

    var body: some View {
        let width = 286 * scale
        let corner = 18 * scale
        let glow = lerp(0.28, 0.62, emphasis)

        VStack(alignment: .leading, spacing: 7 * scale) {
            HStack {
                Text("Travel Adapter")
                    .font(.system(size: 12 * scale, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 8 * scale, height: 8 * scale)
                    .shadow(color: AppTheme.accent.opacity(glow), radius: 8 * scale)
            }
            Text(conversion.sourceText)
                .font(.system(size: 23 * scale, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
            Divider()
                .background(.white.opacity(0.14))
                .scaleEffect(x: lerp(0.78, 1, emphasis), anchor: .leading)
            Text(conversion.convertedText)
                .font(.system(size: 34 * scale, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(AppTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .shadow(color: AppTheme.accent.opacity(glow), radius: lerp(12, 24, emphasis) * scale, y: 2)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppTheme.accent.opacity(0.18 * emphasis))
                        .frame(height: 8 * scale)
                        .offset(y: -4 * scale)
                }
            Text("Detected price · \(conversion.routeText)")
                .font(.system(size: 12 * scale, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16 * scale)
        .padding(.vertical, 14 * scale)
        .frame(width: width, alignment: .leading)
        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: corner).stroke(AppTheme.accent.opacity(lerp(0.72, 0.95, emphasis)), lineWidth: 1.2 * scale))
        .shadow(color: AppTheme.accent.opacity(glow), radius: lerp(14, 26, emphasis) * scale, y: 6 * scale)
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * min(max(progress, 0), 1)
    }
}
