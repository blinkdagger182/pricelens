import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var step = 0
    @State private var surveyAnswers: [String: String] = [:]
    @State private var showOnboardingPaywall = false
    private let permission = CameraPermissionService()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                switch step {
                case 0: welcome
                case 1...3: surveyFlow
                case 4: OnboardingCurrencyGlobePage { goToStep(5) }
                case 5: HomeCurrencySelectionView(selectedCode: $settings.homeCurrencyCode) { goToStep(6) }
                case 6: TravelCurrencySelectionView(selectedCode: $settings.travelCurrencyCode) { showPaywallWithoutPageFlash() }
                default: cameraPermission
                }
            }
            .fullScreenCover(isPresented: $showOnboardingPaywall, onDismiss: {
                goToStep(7)
            }) {
                PriceLensPaywallView()
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            OnboardingHeroView()
                .padding(.top, 6)
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    Text("Welcome to ")
                        .foregroundStyle(AppTheme.textPrimary)
                    PricetagAIWordmark(font: .largeTitle.bold())
                }
                .font(.largeTitle.bold())
                Text("Currency Camera for Travel").font(.title3.bold()).foregroundStyle(AppTheme.textSecondary)
                Text("Point your camera at price tags, menus, or receipts and see converted prices float in place.")
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            PrimaryButton(title: "Continue") { goToStep(1) }
        }
        .padding(24)
    }

    private var surveyFlow: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingProgressHeader(step: surveyIndex + 1, totalSteps: Self.surveyQuestions.count)
            surveyPage(index: surveyIndex)
        }
        .padding(24)
    }

    private func surveyPage(index: Int) -> some View {
        let question = Self.surveyQuestions[index]
        return OnboardingSurveyQuestionView(
            question: question,
            selection: surveySelectionBinding(for: question.id)
        ) {
            goToStep(step + 1)
        }
        .id(question.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.easeOut(duration: 0.24), value: question.id)
    }

    private var surveyIndex: Int {
        min(max(step - 1, 0), Self.surveyQuestions.count - 1)
    }

    private func surveySelectionBinding(for id: String) -> Binding<String> {
        Binding(
            get: { surveyAnswers[id] ?? "" },
            set: { surveyAnswers[id] = $0 }
        )
    }

    private func goToStep(_ nextStep: Int) {
        if step >= 1 && step <= 3 && nextStep >= 1 && nextStep <= 3 {
            withAnimation(.easeOut(duration: 0.22)) {
                step = nextStep
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                step = nextStep
            }
        }
    }

    private func showPaywallWithoutPageFlash() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showOnboardingPaywall = true
        }
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28).fill(.black)
            Text("¥$€").font(.largeTitle.bold()).foregroundStyle(.white)
            ScannerCorners(color: AppTheme.accent, lineWidth: 4)
                .padding(18)
        }
        .frame(width: 112, height: 112)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(AppTheme.border))
    }

    private var cameraPermission: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "camera.viewfinder").font(.system(size: 54)).foregroundStyle(AppTheme.accent)
            Text("Enable Camera Scanning").font(.title.bold())
            Text("Pricetag AI scans visible text on your device and places converted prices over the camera preview.")
                .font(.body)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "Enable Camera") {
                Task {
                    _ = await permission.request()
                    await MainActor.run { settings.hasCompletedOnboarding = true }
                }
            }
            Button("Skip for now") { settings.hasCompletedOnboarding = true }
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(24)
    }

    private static let surveyQuestions: [OnboardingSurveyQuestion] = [
        .init(
            id: "travel_reason",
            eyebrow: "Personalize setup",
            title: "What kind of travel do you use Pricetag AI for?",
            subtitle: "This helps make the first-run experience feel closer to your trips.",
            options: [
                .init(id: "holiday", title: "Holidays", subtitle: "Menus, shops, attractions, and quick travel decisions.", icon: "sun.max.fill"),
                .init(id: "work", title: "Work trips", subtitle: "Receipts, taxis, hotel charges, and business expenses.", icon: "briefcase.fill"),
                .init(id: "living_abroad", title: "Living abroad", subtitle: "Groceries, bills, and daily prices in another currency.", icon: "house.fill")
            ]
        ),
        .init(
            id: "scan_type",
            eyebrow: "Scanning style",
            title: "What will you scan most often?",
            subtitle: "Pricetag AI works live, but Snap is best when there are many prices on one page.",
            options: [
                .init(id: "menus", title: "Restaurant menus", subtitle: "Compare food prices without typing anything.", icon: "fork.knife"),
                .init(id: "tags", title: "Price tags", subtitle: "Point at shelves, signs, and product labels.", icon: "tag.fill"),
                .init(id: "receipts", title: "Receipts", subtitle: "Capture printed totals and line items when live scanning is busy.", icon: "doc.text.fill")
            ]
        ),
        .init(
            id: "confidence",
            eyebrow: "Travel confidence",
            title: "How do you usually think about foreign prices?",
            subtitle: "The app stays camera-first either way. Manual convert is always available.",
            options: [
                .init(id: "instant", title: "I want instant clarity", subtitle: "Show the converted price as soon as Pricetag AI sees it.", icon: "bolt.fill"),
                .init(id: "compare", title: "I compare a few options", subtitle: "Help me scan several prices smoothly.", icon: "rectangle.3.group.fill"),
                .init(id: "double_check", title: "I like to double-check", subtitle: "Let me tap a result and see the rate behind it.", icon: "checkmark.shield.fill")
            ]
        )
    ]
}

struct OnboardingProgressHeader: View {
    let step: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                PricetagAIWordmark(font: .subheadline.bold())
                Spacer()
                Text("\(step)/\(totalSteps)")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.surfaceSecondary)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, Color.white.opacity(0.86)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, proxy.size.width * progress))
                        .shadow(color: AppTheme.accent.opacity(0.36), radius: 8, x: 0, y: 0)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: step)
        }
        .frame(height: 36)
    }

    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        return CGFloat(step) / CGFloat(totalSteps)
    }
}

struct ScannerCorners: View {
    var color: Color = .white
    var lineWidth: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            Path { path in
                let l: CGFloat = min(w, h) * 0.22
                path.move(to: CGPoint(x: 0, y: l)); path.addLine(to: .zero); path.addLine(to: CGPoint(x: l, y: 0))
                path.move(to: CGPoint(x: w - l, y: 0)); path.addLine(to: CGPoint(x: w, y: 0)); path.addLine(to: CGPoint(x: w, y: l))
                path.move(to: CGPoint(x: w, y: h - l)); path.addLine(to: CGPoint(x: w, y: h)); path.addLine(to: CGPoint(x: w - l, y: h))
                path.move(to: CGPoint(x: l, y: h)); path.addLine(to: CGPoint(x: 0, y: h)); path.addLine(to: CGPoint(x: 0, y: h - l))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}
