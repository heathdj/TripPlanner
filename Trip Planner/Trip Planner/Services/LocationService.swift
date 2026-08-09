import CoreLocation
import Foundation

@MainActor
@Observable
final class LocationService: NSObject {
    private let manager: CLLocationManager
    private var locationRequestID = UUID()

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

    func requestAccessOrRefreshLocation() {
        errorMessage = nil

        switch authorizationStatus {
        case .notDetermined:
            isRequestingLocation = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            refreshLocationIfAuthorized()
        case .denied, .restricted:
            isRequestingLocation = false
            currentLocation = nil
        @unknown default:
            isRequestingLocation = false
        }
    }

    func refreshLocationIfAuthorized() {
        guard canUseLocation,
              currentLocation == nil,
              isRequestingLocation == false
        else {
            return
        }

        requestCurrentLocation()
    }

    private func requestCurrentLocation() {
        locationRequestID = UUID()
        isRequestingLocation = true
        manager.startUpdatingLocation()
        manager.requestLocation()
        clearRequestIfLocationDoesNotArrive(requestID: locationRequestID)
    }

    private func clearRequestIfLocationDoesNotArrive(requestID: UUID) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))

            guard locationRequestID == requestID,
                  isRequestingLocation,
                  currentLocation == nil
            else {
                return
            }

            manager.stopUpdatingLocation()
            isRequestingLocation = false
            errorMessage = "Location is enabled, but the device has not returned a location yet. In Simulator, choose a location from Features > Location and try again."
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let updatedAuthorizationStatus = manager.authorizationStatus

        Task { @MainActor in
            authorizationStatus = updatedAuthorizationStatus

            if canUseLocation {
                isRequestingLocation = false
                currentLocation = nil
                requestCurrentLocation()
            } else if isDeniedOrRestricted {
                isRequestingLocation = false
                currentLocation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.manager.stopUpdatingLocation()
            currentLocation = locations.last
            isRequestingLocation = false
            errorMessage = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let message: String
        if let locationError = error as? CLError,
           locationError.code == .locationUnknown {
            message = "Location is enabled, but your current location is not available yet. In Simulator, choose a location from Features > Location and try again."
        } else {
            message = "Trip Planner could not get your current location. Nearby prompts are paused, but date-based prompts still work."
        }

        Task { @MainActor in
            self.manager.stopUpdatingLocation()
            isRequestingLocation = false
            errorMessage = message
        }
    }
}
