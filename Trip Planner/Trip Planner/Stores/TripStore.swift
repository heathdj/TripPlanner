import Foundation

@MainActor
struct TripStore: Sendable {
    var trips: [TripSummary]

    init(trips: [TripSummary] = TripStore.sampleTrips) {
        self.trips = trips
    }

    var activeTrips: [TripSummary] {
        trips.filter { $0.status != .complete }
    }

    var plannedItemTotal: Int {
        trips.reduce(0) { total, trip in
            total + trip.plannedItemCount
        }
    }

    var nextTrip: TripSummary? {
        activeTrips.first
    }

    static let sampleTrips: [TripSummary] = [
        TripSummary(
            id: UUID(uuidString: "5B3F7082-0B28-4D47-9D76-84F47C364501") ?? UUID(),
            title: "Pacific Northwest Loop",
            location: "Seattle, Portland, and the coast",
            dateRange: "Sep 12-20",
            status: .planning,
            highlight: "Coffee walks, ferries, tide pools, and a quiet cabin night.",
            plannedItemCount: 14
        ),
        TripSummary(
            id: UUID(uuidString: "559456CE-F943-45BA-9B98-66E69A9229E8") ?? UUID(),
            title: "Austin Weekend",
            location: "Austin, Texas",
            dateRange: "Oct 3-6",
            status: .nearby,
            highlight: "Live music, barbecue, and a Sunday swim stop.",
            plannedItemCount: 8
        ),
        TripSummary(
            id: UUID(uuidString: "96B6AE50-D84C-4E87-BAB4-0FB9C86D5E80") ?? UUID(),
            title: "Kyoto Spring Notes",
            location: "Kyoto, Japan",
            dateRange: "Apr 2-11",
            status: .booked,
            highlight: "Temples, rail hops, market breakfasts, and garden time.",
            plannedItemCount: 22
        )
    ]
}
