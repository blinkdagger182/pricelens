import SwiftUI

/// Phone-screen story: framing the bag tag → active scan → big conversion (no external screenshot).
struct OnboardingDemoScreenView: View {
    var phase: OnboardingHeroStoryPhase
    var phaseProgress: Double
    var beamOffset: CGFloat
    var elapsed: TimeInterval

    private let cameraCorner: CGFloat = 34
    private let bottomChromeHeight: CGFloat = 152
    private let canvasW: CGFloat = 390
    private let canvasH: CGFloat = 844

    private let itemName = "Travel Adapter"
    private let yen = "¥12,800"
    private let ringgit = "RM 398.40"

    var body: some View {
        VStack(spacing: 0) {
            cameraViewport
                .frame(height: canvasH - bottomChromeHeight - 2)
                .padding(.horizontal, 6)
                .padding(.top, 2)
            bottomChrome
                .frame(height: bottomChromeHeight)
        }
        .frame(width: canvasW, height: canvasH)
        .background(Color.black)
    }

    private var cameraViewport: some View {
        ZStack {
            blendedFeed
            .clipShape(RoundedRectangle(cornerRadius: cameraCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cameraCorner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cameraCorner, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.92), lineWidth: 2.5)
            )
            topChrome
        }
    }

    private var blendedFeed: some View {
        return ZStack {
            if phase == .framing {
                framingFeed
            } else {
                scanRevealFeed(reveal: phase == .reveal ? smoothstep(0.0, 0.8, phaseProgress) : 0)
            }
        }
    }

    // MARK: - Framing (see the bag + tag in the world)

    private var framingFeed: some View {
        let prep = smoothstep(0.72, 1.0, phaseProgress)
        return ZStack {
            leatherBackdrop

            VStack {
                Spacer()
                Text("Align with the price tag")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(.bottom, 22)
            }
            .opacity(Double(1 - prep))

            Image(systemName: "viewfinder")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(AppTheme.accent.opacity(0.65))
                .opacity(Double(1 - prep))

            tagCard
                .scaleEffect(1.55)
                .offset(x: 0, y: -4)

            viewfinderCorners(opacity: 0.35 + phaseProgress * 0.25)
        }
    }

    private var leatherBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#D8C4A6"), Color(hex: "#745C43"), Color(hex: "#221913")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.28), .clear],
                center: .init(x: 0.36, y: 0.22),
                startRadius: 20,
                endRadius: 280
            )
        }
    }

    private var bagSilhouette: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#F6F2E8"), Color(hex: "#B7CBD1")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 208, height: 176)
                .overlay(
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WORLD PLUG")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.black.opacity(0.46))
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.72))
                            .frame(width: 72, height: 54)
                            .overlay(Image(systemName: "powerplug.fill").font(.title).foregroundStyle(.white))
                        Text(itemName)
                            .font(.headline.bold())
                            .foregroundStyle(.black.opacity(0.82))
                    }
                    .padding(18),
                    alignment: .topLeading
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.36), lineWidth: 1.2)
                )
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: "#F8EFE1"))
                .frame(width: 118, height: 48)
                .overlay(
                    Text(yen)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.black)
                )
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.22), lineWidth: 1))
                .offset(x: 58, y: 44)
        }
        .offset(y: 40)
        .shadow(color: .black.opacity(0.55), radius: 20, y: 10)
    }

    private var tagCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: "#F4E8D8"))
                .frame(width: 130, height: 84)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
            VStack(spacing: 4) {
                Text(itemName.uppercased())
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundStyle(.black.opacity(0.5))
                Text(yen)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.black.opacity(0.9))
            }
        }
        .rotationEffect(.degrees(-3))
        .offset(x: 0, y: 10)
    }

    // MARK: - Scanning

    private func scanRevealFeed(reveal: CGFloat) -> some View {
        let easedReveal = easeIn(Double(reveal))
        let revealHandoff = phase == .reveal ? smoothstep(0.0, 0.08, phaseProgress) : 0
        let scanComplete = phase == .scanning ? smoothstep(0.62, 0.82, phaseProgress) : 1
        let scanOut = (1 - smoothstep(0.78, 1.0, easedReveal)) * (1 - scanComplete)
        let darken = 0.54 * CGFloat(easedReveal)
        let scanRounds = min(phaseProgress / 0.62, 1) * 1.5
        let scanWave = 0.5 - 0.5 * cos(scanRounds * .pi * 2)
        let scanLineY = lerp(-10, 22, CGFloat(scanWave))

        return ZStack {
            leatherBackdrop

            tagCard
                .scaleEffect(lerp(1.55, 1.34, CGFloat(easedReveal)))
                .offset(x: 0, y: lerp(-4, -220, CGFloat(easedReveal)))
                .opacity(Double(1 - 0.12 * CGFloat(easedReveal)))

            Color.black.opacity(darken)

            priceScanLine(y: scanLineY)
                .opacity(Double(phase == .scanning ? 1 - scanComplete : 0))
            dashedHuntBox
                .opacity(Double(scanOut))
            ScannerCorners(color: .white, lineWidth: 3.4)
                .frame(width: 156, height: 36)
                .offset(y: 20)
                .opacity(Double(scanOut))

            emphasizedConversionCard(reveal: CGFloat(easedReveal))
                .offset(y: lerp(150, 124, CGFloat(easedReveal)))
                .scaleEffect(lerp(0.92, 1, scanComplete), anchor: .top)
                .opacity(Double(scanComplete * (1 - revealHandoff)))

            viewfinderCorners(opacity: Double(0.55 * scanOut + 0.22 * CGFloat(easedReveal)))
            liveBadge.opacity(Double(scanOut))
        }
    }

    private func priceScanLine(y: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, AppTheme.accent.opacity(0.65), .white.opacity(0.86), AppTheme.accent.opacity(0.65), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 190, height: 2.5)
                .blur(radius: 0.4)
            Rectangle()
                .fill(AppTheme.accent.opacity(0.18))
                .frame(width: 190, height: 18)
                .blur(radius: 8)
        }
        .offset(y: y)
        .shadow(color: AppTheme.accent.opacity(0.65), radius: 9)
        .allowsHitTesting(false)
    }

    private var scanningFeed: some View {
        ZStack {
            leatherBackdrop
            bagSilhouette.opacity(0.45)
            tagCard
                .scaleEffect(1.55)
                .offset(x: 0, y: -4)

            scannerBeam
            dashedHuntBox
            ZStack {
                ScannerCorners(color: .white, lineWidth: 3.4)
                    .frame(width: 226, height: 96)
                VStack(alignment: .leading, spacing: 4) {
                    Text(itemName)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.82))
                    HStack(spacing: 6) {
                        Text(yen)
                            .font(.title3.bold())
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(AppTheme.accent)
                        Text("RM 398")
                            .font(.headline.bold())
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.accent)
                    }
                    Text("Detected · JPY → MYR")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(width: 224, alignment: .leading)
                .background(.black.opacity(0.84), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.accent.opacity(0.9), lineWidth: 1.2))
                .shadow(color: AppTheme.accent.opacity(0.34), radius: 16, y: 4)
                .offset(x: 0, y: 88)
            }
            .offset(y: -18)

            viewfinderCorners(opacity: 0.55)
            liveBadge
        }
    }

    private var scanOverlayCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(itemName)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.82))
            HStack(spacing: 6) {
                Text(yen)
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Image(systemName: "arrow.right")
                    .foregroundStyle(AppTheme.accent)
                Text("RM 398")
                    .font(.headline.bold())
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.accent)
            }
            Text("Detected · JPY → MYR")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 224, alignment: .leading)
        .background(.black.opacity(0.84), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.accent.opacity(0.9), lineWidth: 1.2))
        .shadow(color: AppTheme.accent.opacity(0.34), radius: 16, y: 4)
    }

    private func emphasizedConversionCard(reveal: CGFloat) -> some View {
        let emphasis = smoothstep(0.24, 0.82, Double(reveal))
        return OnboardingConversionCard(scale: 1, emphasis: emphasis)
    }

    private var dashedHuntBox: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                style: StrokeStyle(lineWidth: 1.5, dash: [8, 6], dashPhase: CGFloat(elapsed * 28))
            )
            .foregroundStyle(AppTheme.accent.opacity(0.55))
            .frame(width: 156, height: 36)
            .offset(y: 20)
    }

    private var scannerBeam: some View {
        let shimmer = CGFloat(sin(elapsed * 10)) * 0.5 + 0.5
        return ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: AppTheme.accent.opacity(0.12), location: 0.42),
                            .init(color: AppTheme.accent.opacity(0.65 + shimmer * 0.2), location: 0.5),
                            .init(color: AppTheme.accent.opacity(0.12), location: 0.58),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 28)
                .blur(radius: 6)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.9), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
    }

    // MARK: - Reveal

    private var revealFeed: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "#1A2215"), Color.black],
                center: .center,
                startRadius: 40,
                endRadius: 340
            )

            VStack(spacing: 18) {
                tagCard
                    .scaleEffect(1.55)
                    .offset(y: -4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(itemName)
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.76))
                        Spacer()
                        Circle().fill(AppTheme.accent).frame(width: 8, height: 8)
                    }
                    Text(yen)
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.92))
                    Divider().background(.white.opacity(0.14))
                    Text(ringgit)
                        .font(.system(size: 42, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.accent)
                        .shadow(color: AppTheme.accent.opacity(0.35), radius: 16, y: 2)
                    Text("JPY → MYR · overlay anchored to tag")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: 286)
                .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.accent.opacity(0.85), lineWidth: 1.2))
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 22, y: 8)
            }
            .padding(.horizontal, 24)

            viewfinderCorners(opacity: 0.2 + Double(phaseProgress) * 0.2)
        }
    }

    private var finalConversionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(itemName)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.76))
                Spacer()
                Circle().fill(AppTheme.accent).frame(width: 8, height: 8)
            }
            Text(yen)
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
            Divider().background(.white.opacity(0.14))
            Text(ringgit)
                .font(.system(size: 42, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(AppTheme.accent)
                .shadow(color: AppTheme.accent.opacity(0.35), radius: 16, y: 2)
            Text("JPY → MYR · overlay anchored to tag")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(16)
        .frame(width: 286)
        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.accent.opacity(0.85), lineWidth: 1.2))
        .shadow(color: AppTheme.accent.opacity(0.3), radius: 22, y: 8)
    }

    // MARK: - Chrome

    private var topChrome: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                CurrencyPill(code: "MYR").scaleEffect(0.92)
                Spacer()
                Text("PriceLens").font(.headline.bold()).foregroundStyle(.white)
                Spacer()
                CurrencyPill(code: "JPY").scaleEffect(0.92)
            }
            HStack(spacing: 6) {
                Image(systemName: "text.viewfinder")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                Text("Live camera · OCR prices · Instant conversion")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .allowsHitTesting(false)
    }

    private var liveBadge: some View {
        VStack {
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red.opacity(0.92))
                        .frame(width: 7, height: 7)
                    Text("LIVE")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.red.opacity(0.38)))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func viewfinderCorners(opacity: Double) -> some View {
        let o = opacity * (0.85 + 0.15 * sin(elapsed * 2.5))
        return GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let len: CGFloat = 26
            Path { p in
                p.move(to: CGPoint(x: len, y: 0)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: 0, y: len))
                p.move(to: CGPoint(x: w - len, y: 0)); p.addLine(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: len))
                p.move(to: CGPoint(x: 0, y: h - len)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: len, y: h))
                p.move(to: CGPoint(x: w - len, y: h)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w, y: h - len))
            }
            .stroke(AppTheme.accent.opacity(o), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .allowsHitTesting(false)
    }

    private var bottomChrome: some View {
        ZStack {
            AppTheme.background
            HStack {
                chromeControl(icon: "clock.arrow.circlepath", title: "History")
                Spacer()
                ZStack {
                    Circle().fill(.white).frame(width: 66, height: 66)
                    Circle().stroke(AppTheme.accent, lineWidth: 4).frame(width: 76, height: 76)
                    Image(systemName: "viewfinder").foregroundStyle(.black).font(.title2.bold())
                }
                Spacer()
                chromeControl(icon: "arrow.left.arrow.right", title: "Convert")
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
        }
        .allowsHitTesting(false)
    }

    private func chromeControl(icon: String, title: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption2)
        }
        .foregroundStyle(.white)
        .frame(width: 72)
    }

    private func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> CGFloat {
        guard edge1 > edge0 else { return value >= edge1 ? 1 : 0 }
        let x = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return CGFloat(x * x * (3 - 2 * x))
    }

    private func easeIn(_ value: Double) -> Double {
        let x = min(max(value, 0), 1)
        return x * x * x
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * min(max(progress, 0), 1)
    }
}
