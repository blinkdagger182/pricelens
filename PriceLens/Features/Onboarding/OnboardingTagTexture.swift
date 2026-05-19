import SwiftUI
import UIKit

/// Sticker texture for the 3D price tag — generated, no asset.
enum OnboardingTagTexture {
    @MainActor
    static func make() -> UIImage? {
        let renderer = ImageRenderer(content: tagBody)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private static var tagBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(hex: "#F4E8D8"))
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
            VStack(spacing: 2) {
                Text("HARAJUKU BAG")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.black.opacity(0.55))
                Text("¥12,800")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(.black.opacity(0.92))
                Text("tax incl.")
                    .font(.system(size: 6, weight: .medium))
                    .foregroundStyle(.black.opacity(0.45))
            }
            .padding(.vertical, 5)
        }
        .frame(width: 120, height: 150)
        .background(Color(hex: "#F4E8D8"))
    }
}
