import CoreLocation
import Foundation
import MapKit
import UIKit

enum AppleMapsDirectionsService {
    @MainActor
    static func openDirections(for item: ItineraryItem, in trip: Trip) {
        if let mapItem = coordinateMapItem(for: item) {
            MKMapItem.openMaps(
                with: [.forCurrentLocation(), mapItem],
                launchOptions: drivingLaunchOptions
            )
        } else if let url = searchDirectionsURL(for: item, in: trip) {
            UIApplication.shared.open(url)
        }
    }

    static func searchDirectionsURL(for item: ItineraryItem, in trip: Trip) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: item.searchableDestination(in: trip)),
            URLQueryItem(name: "dirflg", value: "d")
        ]
        return components?.url
    }

    static func coordinateMapItem(for item: ItineraryItem) -> MKMapItem? {
        guard let latitude = item.latitude,
              let longitude = item.longitude
        else {
            return nil
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = item.name
        return mapItem
    }

    static var drivingLaunchOptions: [String: Any] {
        [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
    }
}
