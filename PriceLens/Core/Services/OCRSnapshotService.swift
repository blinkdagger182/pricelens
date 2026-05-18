import Foundation
import CoreGraphics

struct OCRSnapshotService {
    func debugSamples(frame: Int = 0) -> [(String, CGRect)] {
        let phase = CGFloat(frame % 12)
        let drift = sin(phase / 12 * .pi * 2) * 6
        return [
            ("¥1,200", CGRect(x: 120 + drift, y: 220, width: 120, height: 42)),
            ("¥400", CGRect(x: 80, y: 330 + drift * 0.6, width: 90, height: 36)),
            ("¥2,880", CGRect(x: 190 - drift, y: 430, width: 130, height: 42))
        ]
    }
}
