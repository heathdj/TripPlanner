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
    var website: String?
    var pointOfInterestCategoryName: String?
    var timeZoneIdentifier: String?

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
            website: mapItem.url?.absoluteString,
            pointOfInterestCategoryName: mapItem.pointOfInterestCategory?.rawValue,
            timeZoneIdentifier: mapItem.timeZone?.identifier
        )
    }
}

enum PlaceMetadataRefreshService {
    enum RefreshError: LocalizedError, Equatable {
        case missingLookupData
        case noProviderResult

        var errorDescription: String? {
            switch self {
            case .missingLookupData:
                return "This item needs a place identifier, coordinates, or a searchable name before it can refresh."
            case .noProviderResult:
                return "No provider details were found. Saved manual details are still available."
            }
        }
    }

    @MainActor
    static func refreshedItem(_ item: ItineraryItem, in trip: Trip) async throws -> ItineraryItem {
        let mapItem = try await mapItem(for: item, in: trip)
        return item.applyingProviderMetadata(from: mapItem)
    }

    @MainActor
    private static func mapItem(for item: ItineraryItem, in trip: Trip) async throws -> MKMapItem {
        if let identifier = item.mapItemIdentifier,
           let mapItemIdentifier = MKMapItem.Identifier(rawValue: identifier) {
            do {
                let request = MKMapItemRequest(mapItemIdentifier: mapItemIdentifier)
                return try await request.mapItem
            } catch {
                // Fall through to coordinate/name search so stale identifiers do not strand saved activities.
            }
        }

        guard item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw RefreshError.missingLookupData
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = item.searchableDestination(in: trip)
        request.resultTypes = [.address, .pointOfInterest]

        if let latitude = item.latitude,
           let longitude = item.longitude {
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                latitudinalMeters: 10_000,
                longitudinalMeters: 10_000
            )
            request.regionPriority = .required
        }

        let response = try await MKLocalSearch(request: request).start()
        guard let mapItem = response.mapItems.first else {
            throw RefreshError.noProviderResult
        }

        return mapItem
    }
}

extension ItineraryItem {
    func applyingProviderMetadata(from mapItem: MKMapItem, updatedAt: Date = .now) -> ItineraryItem {
        let coordinate = mapItem.location.coordinate
        let providerAddress = mapItem.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
            ?? mapItem.address?.fullAddress
        let providerCategory = mapItem.pointOfInterestCategory?.rawValue

        return ItineraryItem(
            id: id,
            name: name,
            notesOrAddress: notesOrAddress,
            category: category,
            dayNumber: dayNumber,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            mapItemIdentifier: mapItem.identifier?.rawValue ?? mapItemIdentifier,
            phoneNumber: mapItem.phoneNumber ?? phoneNumber,
            pointOfInterestCategoryName: providerCategory ?? pointOfInterestCategoryName,
            placeAddress: mergedProviderValue(providerAddress, current: placeAddress, updatedAt: updatedAt),
            placePhoneNumber: mergedProviderValue(mapItem.phoneNumber, current: placePhoneNumber, updatedAt: updatedAt),
            placeWebsite: mergedProviderValue(mapItem.url?.absoluteString, current: placeWebsite, updatedAt: updatedAt),
            placeCategory: mergedProviderValue(providerCategory, current: placeCategory, updatedAt: updatedAt),
            placeHours: placeHours,
            placeCost: placeCost,
            placeTimeZoneIdentifier: mapItem.timeZone?.identifier ?? placeTimeZoneIdentifier,
            placeAttribution: mergedProviderValue("Apple Maps", current: placeAttribution, updatedAt: updatedAt)
        )
    }

    private func mergedProviderValue(
        _ providerValue: String?,
        current: PlaceDetailValue?,
        updatedAt: Date
    ) -> PlaceDetailValue? {
        guard let providerValue = providerValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              providerValue.isEmpty == false
        else {
            return current
        }

        if current?.source == .user {
            return current
        }

        return PlaceDetailValue(value: providerValue, source: .provider, updatedAt: updatedAt)
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
