import SwiftUI
import UIKit

/// Polished tote + hang tag illustration for the SceneKit prop plane (no ugly box mesh).
struct OnboardingBagPropArt: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#161210"), Color(hex: "#070605")],
                startPoint: .top,
                endPoint: .bottom
            )

            Ellipse()
                .fill(.black.opacity(0.5))
                .blur(radius: 28)
                .frame(width: 240, height: 40)
                .offset(y: 168)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#634133"),
                                Color(hex: "#423021"),
                                Color(hex: "#2A1A12"),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 196, height: 172)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    )

                // Handles
                Capsule()
                    .fill(
                        LinearGradient(colors: [Color(hex: "#1E1410"), Color(hex: "#0D0806")], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 9, height: 64)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -74, y: -58)
                Capsule()
                    .fill(
                        LinearGradient(colors: [Color(hex: "#1E1410"), Color(hex: "#0D0806")], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 9, height: 64)
                    .rotationEffect(.degrees(18))
                    .offset(x: 74, y: -58)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 128, height: 2)
                    .offset(y: -48)
            }
            .offset(y: 14)

            // Hang tag
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(colors: [Color(hex: "#D4B48C"), Color(hex: "#A98658")], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 5, height: 36)
                    .offset(y: -86)

                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: "#F5EBE0"))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                    VStack(spacing: 2) {
                        Text("LEATHER")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.black.opacity(0.42))
                            .tracking(1)
                        Text("¥12,800")
                            .font(.system(size: 17, weight: .bold).monospacedDigit())
                            .foregroundStyle(.black.opacity(0.92))
                        Text("tax incl.")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.black.opacity(0.35))
                    }
                    .padding(.vertical, 4)
                }
                .frame(width: 92, height: 98)
                .offset(x: 58, y: -18)
                .rotationEffect(.degrees(-7))
                .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
            }
        }
        .frame(width: 320, height: 400)
    }
}

enum OnboardingBagPropTexture {
    @MainActor
    static func make() -> UIImage? {
        let content = OnboardingBagPropArt()
            .frame(width: 320, height: 400)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: 320, height: 400)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
