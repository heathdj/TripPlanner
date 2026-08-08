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
        let reviewedItems = items
            .compactMap { item -> ItineraryItem? in
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard name.isEmpty == false else { return nil }

                return ItineraryItem(
                    id: item.id,
                    name: name,
                    notesOrAddress: item.notesOrAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: item.category,
                    dayNumber: item.dayNumber,
                    latitude: item.latitude,
                    longitude: item.longitude,
                    mapItemIdentifier: item.mapItemIdentifier,
                    phoneNumber: item.phoneNumber,
                    pointOfInterestCategoryName: item.pointOfInterestCategoryName,
                    placeAddress: item.placeAddress,
                    placePhoneNumber: item.placePhoneNumber,
                    placeWebsite: item.placeWebsite,
                    placeCategory: item.placeCategory,
                    placeHours: item.placeHours,
                    placeCost: item.placeCost,
                    placeTimeZoneIdentifier: item.placeTimeZoneIdentifier,
                    placeAttribution: item.placeAttribution
                )
            }

        return TripStore.sortedItineraryItems(
            removingDuplicateDepartureItems(from: reviewedItems)
        )
    }

    static func removingDuplicateDepartureItems(from items: [ItineraryItem]) -> [ItineraryItem] {
        let departureItems = items.filter(\.isDepartureEvent)
        guard departureItems.count > 1,
              let keptDepartureID = departureItems.max(by: { lhs, rhs in
                  if lhs.dayNumber == rhs.dayNumber {
                      return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                  }

                  return lhs.dayNumber < rhs.dayNumber
              })?.id
        else {
            return items
        }

        return items.filter { item in
            item.isDepartureEvent == false || item.id == keptDepartureID
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
        trip.updateProgressFromItinerary()
        context.insert(reviewedPlan)
        try context.save()

        return reviewedPlan
    }
}
