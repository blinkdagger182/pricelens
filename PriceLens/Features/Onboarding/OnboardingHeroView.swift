import SwiftUI

struct OnboardingHeroView: View {
    @State private var glowPhase = false
    @State private var isActive = true
    @State private var animationStartTime = ProcessInfo.processInfo.systemUptime
    @State private var demoConversion = OnboardingDemoConversion.fallback

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            let elapsed = max(0, ProcessInfo.processInfo.systemUptime - animationStartTime)
            let phase = OnboardingHeroStory.coarsePhase(at: elapsed)
            let u = OnboardingHeroStory.normalizedTime(elapsed)
            let (_, progress) = OnboardingHeroStory.phase(at: elapsed)
            let handoff = OnboardingHeroStory.conversionCardHandoff(at: elapsed)
            let loopOpacity = OnboardingHeroStory.loopOpacity(at: elapsed)

            let cardT: CGFloat = CGFloat(handoff.expansion)
            let phoneAlpha: Double = phase == .reveal ? Double(1 - smoothstep(0.14, 0.26, progress)) : 1
            let cardStartOffset = CGSize(width: 0, height: 48)
            let cardOffset = CGSize(
                width: lerp(cardStartOffset.width, 0, cardT),
                height: lerp(cardStartOffset.height, 0, cardT)
            )

            VStack(spacing: 10) {
                ZStack {
                    ambientGlow
                    if isActive {
                        iPhone3DHeroSceneView(conversion: demoConversion)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .opacity(phoneAlpha)
                    }
                    standaloneConversionCard()
                        .opacity(handoff.visibility)
                        .scaleEffect(lerp(0.68, 1.0, cardT), anchor: .center)
                        .offset(cardOffset)
                }
                .frame(height: 372)

                storyCaption(phase: phase, cycleT: u)
            }
            .opacity(loopOpacity)
        }
        .frame(height: 428)
        .onAppear {
            isActive = true
            animationStartTime = ProcessInfo.processInfo.systemUptime
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
        }
        .task {
            demoConversion = await OnboardingDemoConversion.current()
        }
        .onDisappear {
            isActive = false
            glowPhase = false
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
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(.black.opacity(0.72), in: Capsule())
            Text(captionSubtitle(phase))
                .font(.subheadline)
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

    private func standaloneConversionCard() -> some View {
        OnboardingConversionCard(scale: 1.18, emphasis: 1, conversion: demoConversion)
    }

    private func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> CGFloat {
        guard edge1 > edge0 else { return value >= edge1 ? 1 : 0 }
        let x = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return CGFloat(x * x * (3 - 2 * x))
    }

    private func easeIn(_ edge0: Double, _ edge1: Double, _ value: Double) -> CGFloat {
        guard edge1 > edge0 else { return value >= edge1 ? 1 : 0 }
        let x = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return CGFloat(x * x * x)
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat, _ t: CGFloat) -> CGFloat {
        from + (to - from) * min(max(t, 0), 1)
    }
}
