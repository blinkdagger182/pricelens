import AVFoundation
import Foundation

enum CameraPermissionState {
    case notDetermined
    case authorized
    case denied
}

struct CameraPermissionService {
    func currentState() -> CameraPermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func request() async -> CameraPermissionState {
        await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
    }
}

