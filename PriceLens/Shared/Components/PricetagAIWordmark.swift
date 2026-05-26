import SwiftUI

struct PricetagAIWordmark: View {
    var font: Font = .headline.bold()

    var body: some View {
        (Text("Pricetag ")
            .foregroundStyle(AppTheme.textPrimary)
         + Text("AI")
            .foregroundStyle(AppTheme.accent))
            .font(font)
    }
}
