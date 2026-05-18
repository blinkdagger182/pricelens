import SwiftUI

extension View {
    func glassSurface(cornerRadius: CGFloat = 18) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
    }
}

