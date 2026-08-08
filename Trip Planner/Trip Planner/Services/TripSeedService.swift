import Foundation
import SwiftData

@MainActor
enum TripSeedService {
    static func seedIfNeeded(in context: ModelContext) throws {
        try seedSettingsIfNeeded(in: context)
        try seedTripsIfNeeded(in: context)
        try context.save()
    }

    private static func seedSettingsIfNeeded(in context: ModelContext) throws {
        _ = try TravelSettingsStore.settings(in: context)
    }

    private static func seedTripsIfNeeded(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Trip>()
        let count = try context.fetchCount(descriptor)

        guard count == 0 else { return }

        let trips = TripStore.sampleTrips
        trips.forEach { context.insert($0) }

        if let firstTrip = trips.first {
            context.insert(
                ReviewedTripPlan(
                    tripID: firstTrip.id,
                    title: "Foundation itinerary review",
                    notes: "Seed reviewed plan used to verify local persistence for generated trip plans."
                )
            )
        }
    }
}
