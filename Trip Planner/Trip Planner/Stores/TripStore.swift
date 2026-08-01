import Foundation

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
                plannedItemCount: 14
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
                plannedItemCount: 8
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
                plannedItemCount: 22
            )
        ]
    }

    private static func sampleDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}
