import Foundation

enum PlaceDetailSource: String, Codable, Hashable, Sendable {
    case provider
    case user
}

nonisolated struct PlaceDetailValue: Codable, Hashable, Sendable {
    var value: String
    var source: PlaceDetailSource
    var updatedAt: Date

    init(value: String, source: PlaceDetailSource, updatedAt: Date = .now) {
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.source = source
        self.updatedAt = updatedAt
    }
}

nonisolated struct ItineraryItem: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var notesOrAddress: String
    var category: ItineraryItemCategory
    var dayNumber: Int
    var latitude: Double?
    var longitude: Double?
    var mapItemIdentifier: String?
    var phoneNumber: String?
    var pointOfInterestCategoryName: String?
    var placeAddress: PlaceDetailValue?
    var placePhoneNumber: PlaceDetailValue?
    var placeWebsite: PlaceDetailValue?
    var placeCategory: PlaceDetailValue?
    var placeHours: PlaceDetailValue?
    var placeCost: PlaceDetailValue?
    var placeTimeZoneIdentifier: String?
    var placeAttribution: PlaceDetailValue?

    init(
        id: UUID = UUID(),
        name: String,
        notesOrAddress: String = "",
        category: ItineraryItemCategory,
        dayNumber: Int,
        latitude: Double? = nil,
        longitude: Double? = nil,
        mapItemIdentifier: String? = nil,
        phoneNumber: String? = nil,
        pointOfInterestCategoryName: String? = nil,
        placeAddress: PlaceDetailValue? = nil,
        placePhoneNumber: PlaceDetailValue? = nil,
        placeWebsite: PlaceDetailValue? = nil,
        placeCategory: PlaceDetailValue? = nil,
        placeHours: PlaceDetailValue? = nil,
        placeCost: PlaceDetailValue? = nil,
        placeTimeZoneIdentifier: String? = nil,
        placeAttribution: PlaceDetailValue? = nil
    ) {
        self.id = id
        self.name = name
        self.notesOrAddress = notesOrAddress
        self.category = category
        self.dayNumber = max(1, dayNumber)
        self.latitude = latitude
        self.longitude = longitude
        self.mapItemIdentifier = mapItemIdentifier
        self.phoneNumber = phoneNumber
        self.pointOfInterestCategoryName = pointOfInterestCategoryName
        self.placeAddress = placeAddress
        self.placePhoneNumber = placePhoneNumber
        self.placeWebsite = placeWebsite
        self.placeCategory = placeCategory
        self.placeHours = placeHours
        self.placeCost = placeCost
        self.placeTimeZoneIdentifier = placeTimeZoneIdentifier
        self.placeAttribution = placeAttribution
    }

    var hasCoordinate: Bool {
        latitude != nil && longitude != nil
    }

    var isDepartureEvent: Bool {
        category == .transit && name.localizedCaseInsensitiveContains("departure")
    }

    var dayDisplayString: String {
        "Day \(dayNumber)"
    }

    var directionsAccessibilityLabel: String {
        "Directions to \(name)"
    }

    var displayAddress: String {
        placeAddress?.value.isEmpty == false ? placeAddress?.value ?? notesOrAddress : notesOrAddress
    }

    var displayPhoneNumber: String {
        placePhoneNumber?.value.isEmpty == false ? placePhoneNumber?.value ?? phoneNumber ?? "" : phoneNumber ?? ""
    }

    var displayWebsite: String {
        placeWebsite?.value ?? ""
    }

    var displayPlaceCategory: String {
        placeCategory?.value.isEmpty == false ? placeCategory?.value ?? pointOfInterestCategoryName ?? "" : pointOfInterestCategoryName ?? ""
    }

    var displayHours: String {
        placeHours?.value ?? ""
    }

    var displayCost: String {
        placeCost?.value ?? ""
    }

    var placeTimeZone: TimeZone? {
        guard let placeTimeZoneIdentifier else { return nil }
        return TimeZone(identifier: placeTimeZoneIdentifier)
    }

    var hasPlaceDetails: Bool {
        [
            displayAddress,
            displayPhoneNumber,
            displayWebsite,
            displayPlaceCategory,
            displayHours,
            displayCost
        ]
        .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    }

    func searchableDestination(in trip: Trip) -> String {
        [name, notesOrAddress, trip.location]
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .joined(separator: ", ")
    }
}
