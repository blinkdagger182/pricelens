import SwiftUI

struct ScannerControlsView: View {
    @Binding var isFrozen: Bool
    var snap: () -> Void
    var showHistory: () -> Void
    var showManual: () -> Void

    var body: some View {
        HStack {
            controlButton(icon: "clock.arrow.circlepath", title: "History", action: showHistory)
            Spacer()
            Button(action: snap) {
                ZStack {
                    Circle().fill(.white).frame(width: 66, height: 66)
                    Circle().stroke(AppTheme.accent, lineWidth: 4).frame(width: 76, height: 76)
                    Image(systemName: "viewfinder").foregroundStyle(.black).font(.title2.bold())
                }
            }
            .buttonStyle(.plain)
            Spacer()
            controlButton(icon: "arrow.left.arrow.right", title: "Convert", action: showManual)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 22)
    }

    private func controlButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(width: 72)
        }
        .buttonStyle(.plain)
    }
}
