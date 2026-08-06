import CoreLocation
import Foundation

@MainActor
@Observable
final class LocationService: NSObject {
    private let manager: CLLocationManager

    var authorizationStatus: CLAuthorizationStatus
    var currentLocation: CLLocation?
    var errorMessage: String?
    var isRequestingLocation = false

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var canUseLocation: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    var isDeniedOrRestricted: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func requestLocationAccess() {
        errorMessage = nil

        switch authorizationStatus {
        case .notDetermined:
            isRequestingLocation = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestCurrentLocation()
        case .denied:
            isRequestingLocation = false
            errorMessage = "Location access is denied. Open Settings to allow Trip Planner to find trips near you."
        case .restricted:
            isRequestingLocation = false
            errorMessage = "Location access is restricted on this device. Trips still appear in Open and Closed sections."
        @unknown default:
            isRequestingLocation = false
            errorMessage = "Trip Planner cannot determine location access right now."
        }
    }

    private func requestCurrentLocation() {
        isRequestingLocation = true
        manager.requestLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            if canUseLocation {
                requestCurrentLocation()
            } else if isDeniedOrRestricted {
                isRequestingLocation = false
                currentLocation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.last
            isRequestingLocation = false
            errorMessage = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            isRequestingLocation = false
            errorMessage = error.localizedDescription
        }
    }
}
