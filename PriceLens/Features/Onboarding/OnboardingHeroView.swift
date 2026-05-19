import SwiftUI

struct OnboardingHeroView: View {
    @State private var glowPhase = false
    @State private var animationStartTime = ProcessInfo.processInfo.systemUptime

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            let elapsed = max(0, ProcessInfo.processInfo.systemUptime - animationStartTime)
            let phase = OnboardingHeroStory.coarsePhase(at: elapsed)
            let u = OnboardingHeroStory.normalizedTime(elapsed)
            let (_, progress) = OnboardingHeroStory.phase(at: elapsed)
            let cardProgress = phase == .reveal ? smoothstep(0.0, 0.55, progress) : 0

            VStack(spacing: 10) {
                ZStack {
                    ambientGlow
                    iPhone3DHeroSceneView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(phase == .reveal ? Double(1 - cardProgress) : 1)
                    standaloneConversionCard(progress: cardProgress)
                        .opacity(Double(cardProgress))
                        .scaleEffect(0.88 + 0.12 * cardProgress)
                }
                .frame(height: 372)

                storyCaption(phase: phase, cycleT: u)
            }
        }
        .frame(height: 428)
        .onAppear {
            animationStartTime = ProcessInfo.processInfo.systemUptime
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
        }
    }

    private var ambientGlow: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(glowPhase ? 0.22 : 0.14))
                .blur(radius: 46)
                .frame(width: 270, height: 270)
                .offset(x: -55, y: 30)
            Circle()
                .fill(Color.white.opacity(glowPhase ? 0.1 : 0.05))
                .blur(radius: 40)
                .frame(width: 200, height: 200)
                .offset(x: 88, y: -88)
        }
    }

    private func storyCaption(phase: OnboardingHeroStoryPhase, cycleT: Double) -> some View {
        VStack(spacing: 6) {
            Text(captionTitle(phase))
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.72), in: Capsule())
            Text(captionSubtitle(phase))
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 58, alignment: .top)
        .allowsHitTesting(false)
    }

    private func captionTitle(_ phase: OnboardingHeroStoryPhase) -> String {
        switch phase {
        case .framing: return "① Spot the real tag"
        case .scanning: return "② PriceLens reads the yen"
        case .reveal: return "③ Your currency, instantly"
        }
    }

    private func captionSubtitle(_ phase: OnboardingHeroStoryPhase) -> String {
        switch phase {
        case .framing: return "Aim at the price tag before you scan."
        case .scanning: return "On-device OCR locks onto the price."
        case .reveal: return "The converted price is shown clearly."
        }
    }

    private func standaloneConversionCard(progress: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Travel Adapter")
                    .font(.headline.bold())
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 10, height: 10)
                    .shadow(color: AppTheme.accent.opacity(0.7), radius: 12)
            }
            Text("¥12,800")
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
            Divider().background(.white.opacity(0.18))
            Text("RM 398.40")
                .font(.system(size: 54, weight: .heavy))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .foregroundStyle(AppTheme.accent)
                .shadow(color: AppTheme.accent.opacity(0.55), radius: 26, y: 4)
            Text("JPY → MYR · converted in place")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(24)
        .frame(width: 326, alignment: .leading)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.accent.opacity(0.95), lineWidth: 1.4))
        .shadow(color: AppTheme.accent.opacity(0.38), radius: 30, y: 10)
        .offset(y: -8 + (1 - progress) * 18)
    }

    private func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> CGFloat {
        guard edge1 > edge0 else { return value >= edge1 ? 1 : 0 }
        let x = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return CGFloat(x * x * (3 - 2 * x))
    }
}
