import SwiftUI

struct OnboardingHeroView: View {
    @State private var glowPhase = false
    @State private var animationStartTime = ProcessInfo.processInfo.systemUptime

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            let elapsed = max(0, ProcessInfo.processInfo.systemUptime - animationStartTime)
            let phase = OnboardingHeroStory.coarsePhase(at: elapsed)
            let u = OnboardingHeroStory.normalizedTime(elapsed)

            ZStack {
                ambientGlow
                iPhone3DHeroSceneView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                storyCaption(phase: phase, cycleT: u)
            }
        }
        .frame(height: 390)
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
        VStack {
            Text(captionTitle(phase))
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.72), in: Capsule())
                .padding(.top, 8)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func captionTitle(_ phase: OnboardingHeroStoryPhase) -> String {
        switch phase {
        case .framing: return "① Spot the real tag"
        case .scanning: return "② PriceLens reads the yen"
        case .reveal: return "③ Your currency, instantly"
        }
    }

    private func floatingConversion(phase: OnboardingHeroStoryPhase, elapsed: TimeInterval) -> some View {
        let show = phase == .reveal
        let pulse = 0.95 + 0.05 * CGFloat(sin(elapsed * 3.5))
        return VStack(alignment: .leading, spacing: 4) {
            Text("¥12,800")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(.white)
            Text("RM 398.40")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.accent.opacity(0.85), lineWidth: 1))
        .shadow(color: AppTheme.accent.opacity(0.35), radius: 18, y: 4)
        .offset(x: 0, y: 128)
        .scaleEffect(show ? pulse : 0.75)
        .opacity(show ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: show)
    }
}
