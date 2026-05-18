import CoreLocation
import Foundation

enum LocationCurrencyError: Error {
    case unavailable
    case denied
    case missingCurrency
}

final class LocationCurrencyService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var continuation: CheckedContinuation<String, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func currentCurrencyCode() async throws -> String {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationCurrencyError.unavailable
        }

        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            throw LocationCurrencyError.denied
        }

        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            resume(with: .failure(LocationCurrencyError.unavailable))
            return
        }

        Task {
            do {
                let placemark = try await geocoder.reverseGeocodeLocation(location).first
                guard let countryCode = placemark?.isoCountryCode,
                      let currencyCode = Locale.currentCurrencyCode(forRegionCode: countryCode) else {
                    resume(with: .failure(LocationCurrencyError.missingCurrency))
                    return
                }
                resume(with: .success(currencyCode))
            } catch {
                resume(with: .failure(error))
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resume(with: .failure(error))
    }

    private func resume(with result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

extension Locale {
    static var deviceCurrencyCode: String {
        Locale.current.currency?.identifier ?? "MYR"
    }

    static func currentCurrencyCode(forRegionCode regionCode: String) -> String? {
        Locale.availableIdentifiers
            .lazy
            .map { Locale(identifier: $0) }
            .first { $0.region?.identifier == regionCode.uppercased() }?
            .currency?
            .identifier
    }
}
