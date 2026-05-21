import SwiftUI
import VisionKit

struct DataScannerRepresentable: UIViewControllerRepresentable {
    var onRecognizedItems: ([(String, CGRect)]) -> Void
    var onUnavailable: () -> Void
    var onReady: () -> Void
    var onCaptureReady: ((@escaping () async -> UIImage?) -> Void)?

    func makeUIViewController(context: Context) -> UIViewController {
        #if targetEnvironment(simulator)
        let controller = UIViewController()
        controller.view.backgroundColor = .black
        DispatchQueue.main.async {
            onCaptureReady?({ nil })
            onUnavailable()
        }
        return controller
        #else
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            let controller = UIViewController()
            controller.view.backgroundColor = .black
            DispatchQueue.main.async {
                onCaptureReady?({ nil })
                onUnavailable()
            }
            return controller
        }
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        let capturePhoto: () async -> UIImage? = { [weak scanner] in
            guard let scanner else { return nil }
            return try? await scanner.capturePhoto()
        }
        DispatchQueue.main.async {
            onCaptureReady?(capturePhoto)
        }
        return ScannerHostViewController(scanner: scanner, onReady: onReady, onUnavailable: onUnavailable)
        #endif
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognizedItems: onRecognizedItems)
    }

    final class ScannerHostViewController: UIViewController {
        private let scanner: DataScannerViewController
        private let onReady: () -> Void
        private let onUnavailable: () -> Void
        private var isScanning = false

        init(scanner: DataScannerViewController, onReady: @escaping () -> Void, onUnavailable: @escaping () -> Void) {
            self.scanner = scanner
            self.onReady = onReady
            self.onUnavailable = onUnavailable
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            addChild(scanner)
            scanner.view.frame = view.bounds
            scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(scanner.view)
            scanner.didMove(toParent: self)
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            startIfNeeded()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            scanner.stopScanning()
            isScanning = false
        }

        private func startIfNeeded() {
            guard !isScanning else { return }
            do {
                try scanner.startScanning()
                isScanning = true
                onReady()
            } catch {
                onUnavailable()
            }
        }
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onRecognizedItems: ([(String, CGRect)]) -> Void
        weak var scanner: DataScannerViewController?

        init(onRecognizedItems: @escaping ([(String, CGRect)]) -> Void) {
            self.onRecognizedItems = onRecognizedItems
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            ingest(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            ingest(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            ingest(allItems)
        }

        private func ingest(_ allItems: [RecognizedItem]) {
            let recognized = allItems.compactMap { item -> (String, CGRect)? in
                guard case .text(let text) = item else { return nil }
                return (text.transcript, Self.rect(from: item.bounds))
            }
            DispatchQueue.main.async { self.onRecognizedItems(recognized) }
        }

        static func rect(from bounds: RecognizedItem.Bounds) -> CGRect {
            let points = [bounds.topLeft, bounds.topRight, bounds.bottomLeft, bounds.bottomRight]
            let minX = points.map(\.x).min() ?? 0
            let maxX = points.map(\.x).max() ?? 0
            let minY = points.map(\.y).min() ?? 0
            let maxY = points.map(\.y).max() ?? 0
            // TODO: Tune on physical devices if VisionKit returns normalized coordinates for a future OS.
            // The helper is intentionally isolated so camera-space mapping can be adjusted in one place.
            return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
        }
    }
}
