import Foundation
import SwiftData

enum ReviewedTripPlanStore {
    enum ValidationError: LocalizedError, Equatable {
        case missingTitle
        case missingItems

        var errorDescription: String? {
            switch self {
            case .missingTitle:
                return "Add a plan title before saving."
            case .missingItems:
                return "Add at least one named itinerary item before saving."
            }
        }
    }

    static func reviewedItems(from items: [ItineraryItem]) -> [ItineraryItem] {
        items
            .compactMap { item in
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard name.isEmpty == false else { return nil }

                return ItineraryItem(
                    id: item.id,
                    name: name,
                    notesOrAddress: item.notesOrAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: item.category,
                    dayNumber: item.dayNumber,
                    latitude: item.latitude,
                    longitude: item.longitude
                )
            }
            .sorted { lhs, rhs in
                if lhs.dayNumber == rhs.dayNumber {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }

                return lhs.dayNumber < rhs.dayNumber
            }
    }

    @MainActor
    static func saveReviewedPlan(
        title: String,
        overview: String,
        items: [ItineraryItem],
        for trip: Trip,
        in context: ModelContext
    ) throws -> ReviewedTripPlan {
        let reviewedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard reviewedTitle.isEmpty == false else {
            throw ValidationError.missingTitle
        }

        let reviewedItems = reviewedItems(from: items)
        guard reviewedItems.isEmpty == false else {
            throw ValidationError.missingItems
        }

        let tripID = trip.id
        let descriptor = FetchDescriptor<ReviewedTripPlan>(
            predicate: #Predicate { plan in
                plan.tripID == tripID
            }
        )
        let existingPlans = try context.fetch(descriptor)
        existingPlans.forEach { context.delete($0) }

        let reviewedPlan = ReviewedTripPlan(
            tripID: trip.id,
            title: reviewedTitle,
            notes: overview.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        trip.itineraryItems = reviewedItems
        trip.updateProgress(completedItems: 0, plannedItems: reviewedItems.count)
        context.insert(reviewedPlan)
        try context.save()

        return reviewedPlan
    }
}
