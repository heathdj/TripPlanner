import Foundation

struct ItineraryItem: Codable, Hashable, Identifiable, Sendable {
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
        pointOfInterestCategoryName: String? = nil
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

    func searchableDestination(in trip: Trip) -> String {
        [name, notesOrAddress, trip.location]
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .joined(separator: ", ")
    }
}
