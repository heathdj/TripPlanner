import CoreLocation
import Foundation
import MapKit

struct DestinationSuggestion: Hashable, Identifiable, Sendable {
    let title: String
    let subtitle: String

    var id: String {
        displayText
    }

    var displayText: String {
        [title, subtitle]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }
}

struct ActivityPlaceSuggestion: Hashable, Identifiable, Sendable {
    let title: String
    let subtitle: String
    var address: String = ""
    var latitude: Double?
    var longitude: Double?
    var mapItemIdentifier: String?
    var phoneNumber: String?
    var pointOfInterestCategoryName: String?

    var id: String {
        [title, subtitle, mapItemIdentifier ?? ""].joined(separator: "|")
    }

    var displayText: String {
        [title, subtitle]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }

    var hasResolvedPlaceDetails: Bool {
        latitude != nil || longitude != nil || address.isEmpty == false
    }
}

@MainActor
@Observable
final class DestinationSuggestionService: NSObject {
    private let completer: MKLocalSearchCompleter

    var suggestions: [DestinationSuggestion] = []

    init(userLocation: CLLocation? = nil) {
        let completer = MKLocalSearchCompleter()
        self.completer = completer
        super.init()
        completer.delegate = self
        completer.resultTypes = .address

        if let userLocation {
            completer.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 2_000_000,
                longitudinalMeters: 2_000_000
            )
            completer.regionPriority = .default
        }
    }

    func updateQuery(_ query: String) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else {
            completer.queryFragment = ""
            suggestions = []
            return
        }

        completer.queryFragment = normalized
    }

    func clearSuggestions() {
        suggestions = []
        completer.queryFragment = ""
    }
}

@MainActor
@Observable
final class ActivityPlaceSearchService: NSObject {
    private let completer: MKLocalSearchCompleter
    private let destination: String
    private let searchCenter: CLLocation?
    private let searchRadiusMeters: CLLocationDistance
    private let searchRegion: MKCoordinateRegion?

    var suggestions: [ActivityPlaceSuggestion] = []
    var errorMessage: String?
    var isResolvingPlace = false

    init(
        destination: String,
        destinationCoordinate: CLLocationCoordinate2D? = nil,
        userLocation: CLLocation? = nil,
        nearYouDistanceKilometers: Double = TravelSettings.defaultNearYouDistanceKilometers
    ) {
        let completer = MKLocalSearchCompleter()
        self.completer = completer
        self.destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        searchRadiusMeters = max(1, nearYouDistanceKilometers) * 1_000

        if let userLocation {
            searchCenter = userLocation
            searchRegion = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: searchRadiusMeters * 2,
                longitudinalMeters: searchRadiusMeters * 2
            )
        } else if let destinationCoordinate {
            searchCenter = CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude)
            searchRegion = MKCoordinateRegion(
                center: destinationCoordinate,
                latitudinalMeters: searchRadiusMeters * 2,
                longitudinalMeters: searchRadiusMeters * 2
            )
        } else {
            searchCenter = nil
            searchRegion = nil
        }

        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]

        if let searchRegion {
            completer.region = searchRegion
            completer.regionPriority = .required
        }
    }

    func updateQuery(_ query: String) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil

        guard normalized.count >= 2 else {
            completer.queryFragment = ""
            suggestions = []
            return
        }

        completer.queryFragment = normalized
    }

    func clearSuggestions() {
        suggestions = []
        completer.queryFragment = ""
    }

    func resolvedSuggestion(for suggestion: ActivityPlaceSuggestion) async -> ActivityPlaceSuggestion {
        await searchFirstPlace(matching: suggestion.displayText)
            ?? suggestion
    }

    func searchEnteredPlace(_ query: String) async -> ActivityPlaceSuggestion? {
        await searchFirstPlace(matching: query)
    }

    private func searchFirstPlace(matching query: String) async -> ActivityPlaceSuggestion? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return nil }

        isResolvingPlace = true
        errorMessage = nil
        defer { isResolvingPlace = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = scopedQuery(normalized)
        request.resultTypes = [.address, .pointOfInterest]

        if let searchRegion {
            request.region = searchRegion
            request.regionPriority = .required
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let mapItem = response.mapItems.first(where: isInsideSearchRadius) else {
                errorMessage = "No matching place found. You can still enter the item manually."
                return nil
            }

            return Self.suggestion(from: mapItem)
        } catch {
            errorMessage = "Place search is unavailable. You can still enter the item manually."
            return nil
        }
    }

    private func scopedQuery(_ query: String) -> String {
        guard destination.isEmpty == false,
              query.localizedCaseInsensitiveContains(destination) == false
        else {
            return query
        }

        return "\(query), \(destination)"
    }

    private func isInsideSearchRadius(_ mapItem: MKMapItem) -> Bool {
        guard let searchCenter else {
            return true
        }

        return mapItem.location.distance(from: searchCenter) <= searchRadiusMeters
    }

    private static func suggestion(from mapItem: MKMapItem) -> ActivityPlaceSuggestion {
        let coordinate = mapItem.location.coordinate
        let address = mapItem.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
            ?? mapItem.address?.fullAddress
            ?? ""
        let title = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines)

        return ActivityPlaceSuggestion(
            title: title?.isEmpty == false ? title ?? "Selected place" : "Selected place",
            subtitle: address,
            address: address,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            mapItemIdentifier: mapItem.identifier?.rawValue,
            phoneNumber: mapItem.phoneNumber,
            pointOfInterestCategoryName: mapItem.pointOfInterestCategory?.rawValue
        )
    }
}

extension DestinationSuggestionService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let completions = completer.results.map { completion in
            DestinationSuggestion(
                title: completion.title,
                subtitle: completion.subtitle
            )
        }

        Task { @MainActor in
            var seen = Set<String>()
            suggestions = completions.filter { suggestion in
                seen.insert(suggestion.displayText).inserted
            }
            .prefix(6)
            .map { $0 }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        Task { @MainActor in
            suggestions = []
        }
    }
}

extension ActivityPlaceSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let completions = completer.results.map { completion in
            ActivityPlaceSuggestion(
                title: completion.title,
                subtitle: completion.subtitle
            )
        }

        Task { @MainActor in
            var seen = Set<String>()
            suggestions = completions.filter { suggestion in
                seen.insert(suggestion.displayText).inserted
            }
            .prefix(6)
            .map { $0 }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        Task { @MainActor in
            suggestions = []
            errorMessage = "Place suggestions are unavailable. You can still enter the item manually."
        }
    }
}
