import CoreGraphics
import Foundation
import UIKit
import Vision

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

    func recognizedText(in image: UIImage) async throws -> [(String, CGRect)] {
        guard let cgImage = image.cgImage else { return [] }
        let size = image.size
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let items = observations.compactMap { observation -> (String, CGRect)? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        let box = observation.boundingBox
                        let rect = CGRect(
                            x: box.minX * size.width,
                            y: (1 - box.maxY) * size.height,
                            width: box.width * size.width,
                            height: box.height * size.height
                        )
                        return (candidate.string, rect)
                    }
                    continuation.resume(returning: items)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["en-US"]

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
