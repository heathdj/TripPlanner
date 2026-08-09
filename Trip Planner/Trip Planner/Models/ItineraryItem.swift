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
    var completionState: ItineraryItemCompletionState
    var completedAt: Date?

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
        placeAttribution: PlaceDetailValue? = nil,
        completionState: ItineraryItemCompletionState = .planned,
        completedAt: Date? = nil
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
        self.completionState = completionState
        self.completedAt = completionState == .completed ? completedAt : nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case notesOrAddress
        case category
        case dayNumber
        case latitude
        case longitude
        case mapItemIdentifier
        case phoneNumber
        case pointOfInterestCategoryName
        case placeAddress
        case placePhoneNumber
        case placeWebsite
        case placeCategory
        case placeHours
        case placeCost
        case placeTimeZoneIdentifier
        case placeAttribution
        case completionState
        case completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: try container.decode(String.self, forKey: .name),
            notesOrAddress: try container.decodeIfPresent(String.self, forKey: .notesOrAddress) ?? "",
            category: try container.decode(ItineraryItemCategory.self, forKey: .category),
            dayNumber: try container.decodeIfPresent(Int.self, forKey: .dayNumber) ?? 1,
            latitude: try container.decodeIfPresent(Double.self, forKey: .latitude),
            longitude: try container.decodeIfPresent(Double.self, forKey: .longitude),
            mapItemIdentifier: try container.decodeIfPresent(String.self, forKey: .mapItemIdentifier),
            phoneNumber: try container.decodeIfPresent(String.self, forKey: .phoneNumber),
            pointOfInterestCategoryName: try container.decodeIfPresent(String.self, forKey: .pointOfInterestCategoryName),
            placeAddress: try container.decodeIfPresent(PlaceDetailValue.self, forKey: .placeAddress),
            placePhoneNumber: try container.decodeIfPresent(PlaceDetailValue.self, forKey: .placePhoneNumber),
            placeWebsite: try container.decodeIfPresent(PlaceDetailValue.self, forKey: .placeWebsite),
            placeCategory: try container.decodeIfPresent(PlaceDetailValue.self, forKey: .placeCategory),
            placeHours: try container.decodeIfPresent(PlaceDetailValue.self, forKey: .placeHours),
            placeCost: try container.decodeIfPresent(PlaceDetailValue.self, forKey: .placeCost),
            placeTimeZoneIdentifier: try container.decodeIfPresent(String.self, forKey: .placeTimeZoneIdentifier),
            placeAttribution: try container.decodeIfPresent(PlaceDetailValue.self, forKey: .placeAttribution),
            completionState: try container.decodeIfPresent(ItineraryItemCompletionState.self, forKey: .completionState) ?? .planned,
            completedAt: try container.decodeIfPresent(Date.self, forKey: .completedAt)
        )
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

    var isCompleted: Bool {
        completionState == .completed
    }

    var isSkipped: Bool {
        completionState == .skipped
    }

    var completionStateAccessibilityLabel: String {
        switch completionState {
        case .planned:
            return "Planned"
        case .completed:
            if let completedAt {
                return "Done \(completedAt.formatted(date: .abbreviated, time: .shortened))"
            }
            return "Done"
        case .skipped:
            return "Skipped"
        }
    }

    mutating func markCompleted(at date: Date = .now) {
        completionState = .completed
        completedAt = date
    }

    mutating func markSkipped() {
        completionState = .skipped
        completedAt = nil
    }

    mutating func markPlanned() {
        completionState = .planned
        completedAt = nil
    }

    func searchableDestination(in trip: Trip) -> String {
        [name, notesOrAddress, trip.location]
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .joined(separator: ", ")
    }
}
