import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var step = 0
    private let permission = CameraPermissionService()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                switch step {
                case 0: welcome
                case 1: HomeCurrencySelectionView(selectedCode: $settings.homeCurrencyCode) { step = 2 }
                case 2: TravelCurrencySelectionView(selectedCode: $settings.travelCurrencyCode) { step = 3 }
                default: cameraPermission
                }
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer()
            appIcon
            VStack(spacing: 10) {
                Text("PriceLens").font(.largeTitle.bold())
                Text("Currency Camera for Travel").font(.headline).foregroundStyle(AppTheme.textSecondary)
                Text("See the real price. Travel smarter.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            PrimaryButton(title: "Continue") { step = 1 }
        }
        .padding(24)
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
            Text("PriceLens scans visible text on your device and places converted prices over the camera preview.")
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

