import UIKit

struct HapticsService {
    func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

