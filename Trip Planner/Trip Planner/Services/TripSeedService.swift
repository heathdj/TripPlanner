import Foundation
import SwiftData

@MainActor
enum TripSeedService {
    private enum UITestScenario: String {
        case zeroActive
        case oneActive
        case multipleActive
    }

    private static let uiTestScenarioEnvironmentKey = "TRIP_PLANNER_UI_TEST_SCENARIO"

    static func seedIfNeeded(in context: ModelContext) throws {
        try seedSettingsIfNeeded(in: context)
        try seedTripsIfNeeded(in: context)
        try context.save()
    }

    static func seedUITestScenarioIfNeeded(in context: ModelContext) throws -> Bool {
        guard let rawScenario = ProcessInfo.processInfo.environment[uiTestScenarioEnvironmentKey],
              let scenario = UITestScenario(rawValue: rawScenario)
        else {
            return false
        }

        try resetPersistentModels(in: context)
        try seedSettingsIfNeeded(in: context)
        let trips = try trips(for: scenario)
        trips.forEach { context.insert($0) }
        try context.save()
        return true
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

    private static func resetPersistentModels(in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<ReviewedTripPlan>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Trip>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<TravelSettings>()).forEach { context.delete($0) }
    }

    private static func trips(for scenario: UITestScenario) throws -> [Trip] {
        switch scenario {
        case .zeroActive:
            return [
                Trip(
                    title: "UI Test Planned",
                    location: "Austin, Texas",
                    windowStartDate: Calendar.current.date(byAdding: .day, value: 12, to: .now) ?? .now,
                    windowEndDate: Calendar.current.date(byAdding: .day, value: 18, to: .now) ?? .now,
                    durationDays: 3,
                    status: .planned,
                    highlight: "Seeded planned trip for launch routing tests.",
                    itineraryItems: [
                        ItineraryItem(name: "Exact hotel", category: .stay, dayNumber: 1, latitude: 30.2490, longitude: -97.7495)
                    ],
                    exactStartDate: Calendar.current.date(byAdding: .day, value: 12, to: .now)
                )
            ]
        case .oneActive:
            let trip = activeTrip(
                title: "Launch Active Solo",
                location: "Chicago, Illinois",
                offset: 0
            )
            try TripLifecycleService.activate(trip, at: Calendar.current.startOfDay(for: .now))
            return [trip]
        case .multipleActive:
            let first = activeTrip(
                title: "Launch Active Alpha",
                location: "Rome, Italy",
                offset: 0
            )
            let second = activeTrip(
                title: "Launch Active Beta",
                location: "Sydney, Australia",
                offset: 1
            )
            try TripLifecycleService.activate(first, at: Calendar.current.startOfDay(for: .now))
            try TripLifecycleService.activate(second, at: Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now))
            return [first, second]
        }
    }

    private static func activeTrip(title: String, location: String, offset: Int) -> Trip {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let windowStart = calendar.date(byAdding: .day, value: -2 - offset, to: today) ?? today
        let windowEnd = calendar.date(byAdding: .day, value: 5 + offset, to: today) ?? today

        return Trip(
            title: title,
            location: location,
            windowStartDate: windowStart,
            windowEndDate: windowEnd,
            durationDays: 4,
            highlight: "Seeded active trip for launch routing tests.",
            plannedItemCount: 2,
            completedItemCount: 1,
            itineraryItems: [
                ItineraryItem(name: "Check in", category: .stay, dayNumber: 1, latitude: 41.8781, longitude: -87.6298),
                ItineraryItem(name: "Dinner", category: .food, dayNumber: 2)
            ]
        )
    }
}
