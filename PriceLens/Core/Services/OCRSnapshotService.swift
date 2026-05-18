import Foundation
import CoreGraphics

struct OCRSnapshotService {
    func debugSamples() -> [(String, CGRect)] {
        [
            ("¥1,200", CGRect(x: 120, y: 220, width: 120, height: 42)),
            ("¥400", CGRect(x: 80, y: 330, width: 90, height: 36)),
            ("¥2,880", CGRect(x: 190, y: 430, width: 130, height: 42))
        ]
    }
}

