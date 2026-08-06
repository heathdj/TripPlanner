import CoreLocation
import Foundation

struct NearbyTrip: Identifiable {
    let trip: Trip
    let distanceMeters: CLLocationDistance

    var id: UUID {
        trip.id
    }
}

struct TripGroups {
    let nearbyTrips: [NearbyTrip]
    let openTrips: [Trip]
    let closedTrips: [Trip]
}

@MainActor
enum TripStore {
    static func sortedOpenTrips(_ trips: [Trip]) -> [Trip] {
        trips
            .filter { $0.status == .open }
            .sorted {
                if $0.windowStartDate == $1.windowStartDate {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                return $0.windowStartDate < $1.windowStartDate
            }
    }

    static func sortedClosedTrips(_ trips: [Trip]) -> [Trip] {
        trips
            .filter { $0.status == .closed }
            .sorted {
                if $0.windowEndDate == $1.windowEndDate {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                return $0.windowEndDate > $1.windowEndDate
            }
    }

    static func sortedTrips(_ trips: [Trip]) -> [Trip] {
        sortedOpenTrips(trips) + sortedClosedTrips(trips)
    }

    static func groupedTrips(
        _ trips: [Trip],
        userLocation: CLLocation?,
        nearYouDistanceKilometers: Double
    ) -> TripGroups {
        let openTrips = sortedOpenTrips(trips)
        let closedTrips = sortedClosedTrips(trips)

        guard let userLocation else {
            return TripGroups(
                nearbyTrips: [],
                openTrips: openTrips,
                closedTrips: closedTrips
            )
        }

        let radiusMeters = max(1, nearYouDistanceKilometers) * 1_000
        let nearbyTrips = openTrips
            .compactMap { trip -> NearbyTrip? in
                guard let distanceMeters = distanceMeters(from: userLocation, to: trip),
                      distanceMeters <= radiusMeters
                else {
                    return nil
                }

                return NearbyTrip(trip: trip, distanceMeters: distanceMeters)
            }
            .sorted {
                if $0.distanceMeters == $1.distanceMeters {
                    return $0.trip.title.localizedStandardCompare($1.trip.title) == .orderedAscending
                }
                return $0.distanceMeters < $1.distanceMeters
            }

        let nearbyIDs = Set(nearbyTrips.map(\.trip.id))

        return TripGroups(
            nearbyTrips: nearbyTrips,
            openTrips: openTrips.filter { nearbyIDs.contains($0.id) == false },
            closedTrips: closedTrips
        )
    }

    static func summaries(from trips: [Trip]) -> [TripSummary] {
        sortedTrips(trips).map { $0.summary() }
    }

    static var sampleTrips: [Trip] {
        [
            Trip(
                id: UUID(uuidString: "5B3F7082-0B28-4D47-9D76-84F47C364501") ?? UUID(),
                title: "Pacific Northwest Loop",
                location: "Seattle, Portland, and the coast",
                windowStartDate: sampleDate(year: 2026, month: 9, day: 12),
                windowEndDate: sampleDate(year: 2026, month: 9, day: 26),
                durationDays: 4,
                status: .open,
                highlight: "Coffee walks, ferries, tide pools, and a quiet cabin night.",
                plannedItemCount: 14,
                completedItemCount: 6,
                travelerCount: 2,
                itineraryItems: [
                    ItineraryItem(
                        name: "Pike Place Market",
                        notesOrAddress: "85 Pike St, Seattle, WA",
                        category: .food,
                        dayNumber: 1,
                        latitude: 47.6097,
                        longitude: -122.3425
                    ),
                    ItineraryItem(
                        name: "Bainbridge ferry loop",
                        notesOrAddress: "Seattle ferry terminal",
                        category: .transit,
                        dayNumber: 2
                    ),
                    ItineraryItem(
                        name: "Cannon Beach tide pools",
                        notesOrAddress: "Haystack Rock, Cannon Beach, OR",
                        category: .activity,
                        dayNumber: 3,
                        latitude: 45.8845,
                        longitude: -123.9651
                    ),
                    ItineraryItem(
                        name: "Coast cabin",
                        notesOrAddress: "Quiet cabin night near Cannon Beach",
                        category: .stay,
                        dayNumber: 3
                    )
                ],
                latitude: 47.6062,
                longitude: -122.3321
            ),
            Trip(
                id: UUID(uuidString: "559456CE-F943-45BA-9B98-66E69A9229E8") ?? UUID(),
                title: "Austin Weekend",
                location: "Austin, Texas",
                windowStartDate: sampleDate(year: 2026, month: 10, day: 3),
                windowEndDate: sampleDate(year: 2026, month: 10, day: 17),
                durationDays: 3,
                status: .open,
                highlight: "Live music, barbecue, and a Sunday swim stop.",
                plannedItemCount: 8,
                completedItemCount: 3,
                travelerCount: 4,
                itineraryItems: [
                    ItineraryItem(
                        name: "South Congress Hotel",
                        notesOrAddress: "1603 S Congress Ave, Austin, TX",
                        category: .stay,
                        dayNumber: 1,
                        latitude: 30.2490,
                        longitude: -97.7495
                    ),
                    ItineraryItem(
                        name: "East Austin barbecue lunch",
                        notesOrAddress: "barbecue near East 11th Street",
                        category: .food,
                        dayNumber: 2
                    ),
                    ItineraryItem(
                        name: "Red River live music",
                        notesOrAddress: "Red River Cultural District",
                        category: .activity,
                        dayNumber: 2,
                        latitude: 30.2695,
                        longitude: -97.7367
                    ),
                    ItineraryItem(
                        name: "Barton Springs Pool",
                        notesOrAddress: "2201 Barton Springs Rd, Austin, TX",
                        category: .activity,
                        dayNumber: 3,
                        latitude: 30.2641,
                        longitude: -97.7713
                    )
                ],
                latitude: 30.2672,
                longitude: -97.7431
            ),
            Trip(
                id: UUID(uuidString: "96B6AE50-D84C-4E87-BAB4-0FB9C86D5E80") ?? UUID(),
                title: "Kyoto Spring Notes",
                location: "Kyoto, Japan",
                windowStartDate: sampleDate(year: 2026, month: 4, day: 2),
                windowEndDate: sampleDate(year: 2026, month: 4, day: 16),
                durationDays: 10,
                status: .closed,
                highlight: "Temples, rail hops, market breakfasts, and garden time.",
                plannedItemCount: 22,
                completedItemCount: 22,
                travelerCount: 2,
                itineraryItems: [
                    ItineraryItem(
                        name: "Fushimi Inari Taisha",
                        notesOrAddress: "68 Fukakusa Yabunouchicho, Fushimi Ward",
                        category: .activity,
                        dayNumber: 1,
                        latitude: 34.9671,
                        longitude: 135.7727
                    ),
                    ItineraryItem(
                        name: "Nishiki Market breakfast",
                        notesOrAddress: "Nishikikoji-dori, Kyoto",
                        category: .food,
                        dayNumber: 2
                    ),
                    ItineraryItem(
                        name: "Arashiyama rail hop",
                        notesOrAddress: "Saga-Arashiyama Station",
                        category: .transit,
                        dayNumber: 3,
                        latitude: 35.0186,
                        longitude: 135.6812
                    ),
                    ItineraryItem(
                        name: "Philosopher's Path garden afternoon",
                        notesOrAddress: "Sakyo Ward, Kyoto",
                        category: .activity,
                        dayNumber: 4
                    )
                ],
                latitude: 35.0116,
                longitude: 135.7681
            )
        ]
    }

    private static func distanceMeters(from location: CLLocation, to trip: Trip) -> CLLocationDistance? {
        guard let latitude = trip.latitude,
              let longitude = trip.longitude
        else {
            return nil
        }

        return location.distance(from: CLLocation(latitude: latitude, longitude: longitude))
    }

    private static func sampleDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}
