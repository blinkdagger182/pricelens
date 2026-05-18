import SwiftUI

struct PriceOverlayLayer: View {
    let items: [PriceOverlayItem]
    var onTap: (PriceOverlayItem) -> Void

    var body: some View {
        ZStack {
            ForEach(items) { item in
                ScannerCorners(color: .white, lineWidth: 3)
                    .frame(width: max(item.bounds.width, 44), height: max(item.bounds.height, 28))
                    .position(x: item.bounds.midX, y: item.bounds.midY)
                    .allowsHitTesting(false)
                PriceOverlayCard(item: item)
                    .position(item.displayPoint)
                    .onTapGesture { onTap(item) }
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
    }
}

