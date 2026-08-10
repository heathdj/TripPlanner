import Foundation
import CoreLocation
import MapKit
import SwiftData
import Testing
@testable import Trip_Planner

struct TripPlannerFoundationTests {
    @MainActor
    @Test("A trip window and trip duration are distinct", .bug("https://github.com/heathdj/TripPlanner/issues/2"))
    func flexibleWindowKeepsDurationSeparate() {
        let trip = Trip(
            title: "Flexible week",
            location: "Denver",
            windowStartDate: date(year: 2026, month: 1, day: 1),
            windowEndDate: date(year: 2026, month: 1, day: 15),
            durationDays: 4
        )

        #expect(trip.windowLengthDays == 15)
        #expect(trip.durationDays == 4)
        #expect(trip.validStartDateCount == 12)
        #expect(trip.durationDisplayString == "4 days")
        #expect(trip.startDateDisplayString == "12 possible start dates")
    }

    @MainActor
    @Test("Invalid trip window inputs are clamped safely", .bug("https://github.com/heathdj/TripPlanner/issues/2"))
    func invalidWindowInputsAreSafe() {
        let trip = Trip(
            title: "Backwards window",
            location: "Chicago",
            windowStartDate: date(year: 2026, month: 2, day: 10),
            windowEndDate: date(year: 2026, month: 2, day: 1),
            durationDays: 0
        )

        #expect(trip.windowLengthDays == 1)
        #expect(trip.durationDays == 1)
        #expect(trip.validStartDateCount == 1)
    }

    @MainActor
    @Test("Trip list facts expose travelers and exact itinerary progress", .bug("https://github.com/heathdj/TripPlanner/issues/4"))
    func tripListFactsExposeTravelersAndExactItineraryProgress() {
        let trip = Trip(
            title: "Fact check",
            location: "Test",
            windowStartDate: date(year: 2026, month: 6, day: 1),
            windowEndDate: date(year: 2026, month: 6, day: 10),
            durationDays: 4,
            plannedItemCount: 5,
            completedItemCount: 9,
            travelerCount: 0,
            itineraryItems: [
                ItineraryItem(name: "Arrive", category: .transit, dayNumber: 0, latitude: 41.88, longitude: -87.63),
                ItineraryItem(name: "Explore", category: .activity, dayNumber: 2)
            ]
        )
        let summary = trip.summary()

        #expect(trip.completedItemCount == 5)
        #expect(trip.travelerCount == 1)
        #expect(trip.progressDisplayString == "1 of 2 planned")
        #expect(trip.progressFraction == 0.5)
        #expect(summary.travelerSummary == "1 traveler")
        #expect(summary.progressSummary == "1 of 2 planned")
        #expect(summary.plannedItemCount == 2)
        #expect(summary.completedItemCount == 1)
        #expect(trip.itineraryItems.map(\.name) == ["Arrive", "Explore"])
        #expect(trip.itineraryItems[0].dayNumber == 1)
    }

    @MainActor
    @Test("Exact itinerary items drive plan progress", .bug("https://github.com/heathdj/TripPlanner/issues/49"))
    func exactItineraryItemsDrivePlanProgress() {
        let trip = Trip(
            title: "Progress",
            location: "Rome",
            windowStartDate: date(year: 2026, month: 6, day: 1),
            windowEndDate: date(year: 2026, month: 6, day: 8),
            durationDays: 4,
            itineraryItems: [
                ItineraryItem(name: "Hotel", category: .stay, dayNumber: 1, latitude: 41.9028, longitude: 12.4964),
                ItineraryItem(name: "Museum", category: .activity, dayNumber: 2, latitude: 41.8902, longitude: 12.4922),
                ItineraryItem(name: "Dinner", category: .food, dayNumber: 2, latitude: 41.9009, longitude: 12.4833),
                ItineraryItem(name: "Walking idea", category: .activity, dayNumber: 3)
            ]
        )

        trip.updateProgressFromItinerary()

        #expect(trip.plannedItemCount == 4)
        #expect(trip.completedItemCount == 3)
        #expect(trip.progressDisplayString == "3 of 4 planned")
        #expect(trip.progressFraction == 0.75)
    }

    @MainActor
    @Test("Active trip item states drive completion progress", .bug("https://github.com/heathdj/TripPlanner/issues/13"))
    func activeTripItemStatesDriveCompletionProgress() throws {
        let doneAt = date(year: 2026, month: 6, day: 4, hour: 14, timeZone: TimeZone(secondsFromGMT: 0) ?? .current)
        let trip = Trip(
            title: "Active Progress",
            location: "Rome",
            windowStartDate: date(year: 2026, month: 6, day: 1),
            windowEndDate: date(year: 2026, month: 6, day: 8),
            durationDays: 4,
            itineraryItems: [
                ItineraryItem(name: "Hotel", category: .stay, dayNumber: 1, latitude: 41.9028, longitude: 12.4964),
                ItineraryItem(name: "Museum", category: .activity, dayNumber: 2, latitude: 41.8902, longitude: 12.4922),
                ItineraryItem(name: "Dinner", category: .food, dayNumber: 2),
                ItineraryItem(name: "Walk", category: .activity, dayNumber: 3)
            ]
        )

        try TripLifecycleService.activate(trip, at: date(year: 2026, month: 6, day: 1))
        trip.itineraryItems[0].markCompleted(at: doneAt)
        trip.itineraryItems[1].markCompleted(at: doneAt)
        trip.itineraryItems[2].markSkipped()
        trip.updateProgressFromItinerary()

        #expect(trip.progressDisplayString == "2 of 4 done")
        #expect(trip.progressAccessibilityValue == "2 of 4 done, 50 percent")
        #expect(trip.progressFraction == 0.5)
        #expect(trip.completedItemCount == 2)
        #expect(trip.skippedActionableItemCount == 1)
        #expect(trip.itineraryItems[0].completedAt == doneAt)

        trip.itineraryItems[0].markPlanned()
        trip.updateProgressFromItinerary()

        #expect(trip.progressDisplayString == "1 of 4 done")
        #expect(trip.progressFraction == 0.25)
        #expect(trip.itineraryItems[0].completedAt == nil)
    }

    @MainActor
    @Test("Planned trips keep plan progress separate from completion state", .bug("https://github.com/heathdj/TripPlanner/issues/13"))
    func plannedTripsKeepPlanProgressSeparateFromCompletionState() {
        let trip = Trip(
            title: "Still Planning",
            location: "Austin",
            windowStartDate: date(year: 2026, month: 10, day: 1),
            windowEndDate: date(year: 2026, month: 10, day: 8),
            durationDays: 3,
            status: .planned,
            itineraryItems: [
                ItineraryItem(name: "Exact hotel", category: .stay, dayNumber: 1, latitude: 30.249, longitude: -97.7495, completionState: .completed, completedAt: .now),
                ItineraryItem(name: "Loose dinner", category: .food, dayNumber: 2)
            ]
        )

        trip.updateProgressFromItinerary()

        #expect(trip.progressDisplayString == "1 of 2 planned")
        #expect(trip.progressFraction == 0.5)
        #expect(trip.completedItemCount == 1)
    }

    @MainActor
    @Test("Closed trips preserve item completion progress", .bug("https://github.com/heathdj/TripPlanner/issues/13"))
    func closedTripsPreserveItemCompletionProgress() throws {
        let trip = Trip(
            title: "Closed Progress",
            location: "Santa Fe",
            windowStartDate: date(year: 2026, month: 3, day: 1),
            windowEndDate: date(year: 2026, month: 3, day: 8),
            durationDays: 4,
            itineraryItems: [
                ItineraryItem(name: "Museum", category: .activity, dayNumber: 1),
                ItineraryItem(name: "Dinner", category: .food, dayNumber: 2)
            ]
        )

        try TripLifecycleService.activate(trip, at: date(year: 2026, month: 3, day: 1))
        trip.itineraryItems[0].markCompleted(at: date(year: 2026, month: 3, day: 2))
        trip.updateProgressFromItinerary()
        try TripLifecycleService.close(trip, outcome: .completed, at: date(year: 2026, month: 3, day: 5))

        #expect(trip.progressDisplayString == "1 of 2 done")
        #expect(trip.progressFraction == 0.5)
        #expect(trip.summary().progressSummary == "1 of 2 done")
    }

    @MainActor
    @Test("Active trip completion progress handles empty plans", .bug("https://github.com/heathdj/TripPlanner/issues/13"))
    func activeTripCompletionProgressHandlesEmptyPlans() throws {
        let trip = Trip(
            title: "Empty Active",
            location: "Chicago",
            windowStartDate: date(year: 2026, month: 5, day: 1),
            windowEndDate: date(year: 2026, month: 5, day: 6),
            durationDays: 2
        )

        try TripLifecycleService.activate(trip, at: date(year: 2026, month: 5, day: 1))
        trip.updateProgressFromItinerary()

        #expect(trip.progressDisplayString == "0 of 0 done")
        #expect(trip.progressAccessibilityValue == "0 of 0 done, 0 percent")
        #expect(trip.progressFraction == 0)
    }

    @Test("Older itinerary item payloads decode with planned completion state", .bug("https://github.com/heathdj/TripPlanner/issues/13"))
    func olderItineraryItemPayloadsDecodeWithPlannedCompletionState() throws {
        let data = Data(
            #"""
            {
                "id": "39B985D3-8E1E-4E57-8AE5-C3C1E1D58013",
                "name": "Museum",
                "notesOrAddress": "Main Street",
                "category": "activity",
                "dayNumber": 2
            }
            """#.utf8
        )

        let item = try JSONDecoder().decode(ItineraryItem.self, from: data)

        #expect(item.completionState == .planned)
        #expect(item.completedAt == nil)
    }

    @MainActor
    @Test("Itinerary items model directions data safely", .bug("https://github.com/heathdj/TripPlanner/issues/5"))
    func itineraryItemsModelDirectionsDataSafely() {
        let exact = ItineraryItem(
            name: "Museum",
            notesOrAddress: "100 Main St",
            category: .activity,
            dayNumber: 2,
            latitude: 41.88,
            longitude: -87.63
        )
        let generated = ItineraryItem(
            name: "Best ramen",
            notesOrAddress: "near station",
            category: .food,
            dayNumber: -4
        )
        let trip = Trip(
            title: "Tokyo",
            location: "Tokyo, Japan",
            windowStartDate: date(year: 2026, month: 7, day: 1),
            windowEndDate: date(year: 2026, month: 7, day: 8),
            durationDays: 4,
            itineraryItems: [exact, generated]
        )

        #expect(exact.hasCoordinate)
        #expect(generated.hasCoordinate == false)
        #expect(generated.dayNumber == 1)
        #expect(generated.searchableDestination(in: trip) == "Best ramen, near station, Tokyo, Japan")
        #expect(generated.directionsAccessibilityLabel == "Directions to Best ramen")
    }

    @MainActor
    @Test("Apple Maps fallback searches trip-scoped destinations", .bug("https://github.com/heathdj/TripPlanner/issues/5"))
    func appleMapsFallbackSearchesTripScopedDestinations() throws {
        let trip = Trip(
            title: "Austin",
            location: "Austin, Texas",
            windowStartDate: date(year: 2026, month: 8, day: 1),
            windowEndDate: date(year: 2026, month: 8, day: 6),
            durationDays: 3
        )
        let item = ItineraryItem(
            name: "Breakfast tacos",
            notesOrAddress: "near South Congress",
            category: .food,
            dayNumber: 1
        )

        let url = try #require(AppleMapsDirectionsService.searchDirectionsURL(for: item, in: trip))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        #expect(components.host == "maps.apple.com")
        #expect(queryItems.first { $0.name == "daddr" }?.value == "Breakfast tacos, near South Congress, Austin, Texas")
        #expect(queryItems.first { $0.name == "dirflg" }?.value == "d")
        #expect(AppleMapsDirectionsService.coordinateMapItem(for: item) == nil)
    }

    @MainActor
    @Test("Reviewed itinerary items preserve selected place metadata", .bug("https://github.com/heathdj/TripPlanner/issues/45"))
    func reviewedItineraryItemsPreserveSelectedPlaceMetadata() {
        let item = ItineraryItem(
            name: "Opera House",
            notesOrAddress: "Bennelong Point, Sydney NSW, Australia",
            category: .activity,
            dayNumber: 1,
            latitude: -33.8568,
            longitude: 151.2153,
            mapItemIdentifier: "apple-map-item-id",
            phoneNumber: "+61 2 9250 7111",
            pointOfInterestCategoryName: "MKPOICategoryTheater",
            placeWebsite: PlaceDetailValue(value: "https://www.sydneyoperahouse.com", source: .provider),
            placeHours: PlaceDetailValue(value: "10:00 AM-5:00 PM", source: .user),
            placeCost: PlaceDetailValue(value: "AUD 45-75", source: .user),
            placeTimeZoneIdentifier: "Australia/Sydney",
            placeAttribution: PlaceDetailValue(value: "Apple Maps", source: .provider)
        )

        let reviewedItems = ReviewedTripPlanStore.reviewedItems(from: [item])

        #expect(reviewedItems.first?.mapItemIdentifier == "apple-map-item-id")
        #expect(reviewedItems.first?.phoneNumber == "+61 2 9250 7111")
        #expect(reviewedItems.first?.pointOfInterestCategoryName == "MKPOICategoryTheater")
        #expect(reviewedItems.first?.placeWebsite?.value == "https://www.sydneyoperahouse.com")
        #expect(reviewedItems.first?.placeHours?.source == .user)
        #expect(reviewedItems.first?.placeCost?.value == "AUD 45-75")
        #expect(reviewedItems.first?.placeTimeZoneIdentifier == "Australia/Sydney")
        #expect(reviewedItems.first?.placeAttribution?.source == .provider)
        #expect(reviewedItems.first?.hasCoordinate == true)
    }

    @MainActor
    @Test("Provider metadata refresh preserves manual overrides", .bug("https://github.com/heathdj/TripPlanner/issues/46"))
    func providerMetadataRefreshPreservesManualOverrides() throws {
        let item = ItineraryItem(
            name: "Museum",
            notesOrAddress: "Manual address",
            category: .activity,
            dayNumber: 1,
            placePhoneNumber: PlaceDetailValue(value: "555-0100", source: .user),
            placeWebsite: PlaceDetailValue(value: "https://old.example.com", source: .provider),
            placeHours: PlaceDetailValue(value: "Closed Tuesdays", source: .user),
            placeCost: PlaceDetailValue(value: "Free", source: .user)
        )
        let mapItem = MKMapItem(
            location: CLLocation(latitude: 41.8902, longitude: 12.4922),
            address: nil
        )
        mapItem.name = "Museum"
        mapItem.phoneNumber = "555-9999"
        mapItem.url = URL(string: "https://provider.example.com")
        mapItem.pointOfInterestCategory = .museum
        mapItem.timeZone = TimeZone(identifier: "Europe/Rome")

        let refreshed = item.applyingProviderMetadata(from: mapItem)

        #expect(refreshed.placePhoneNumber?.value == "555-0100")
        #expect(refreshed.placePhoneNumber?.source == .user)
        #expect(refreshed.placeWebsite?.value == "https://provider.example.com")
        #expect(refreshed.placeWebsite?.source == .provider)
        #expect(refreshed.placeHours?.value == "Closed Tuesdays")
        #expect(refreshed.placeCost?.value == "Free")
        #expect(refreshed.placeTimeZoneIdentifier == "Europe/Rome")
        #expect(refreshed.placeAttribution?.value == "Apple Maps")
    }

    @MainActor
    @Test("Open trips sort by upcoming window", .bug("https://github.com/heathdj/TripPlanner/issues/2"))
    func openTripsSortByUpcomingWindow() {
        let late = trip(title: "Late", startDay: 20, endDay: 24, status: .open)
        let early = trip(title: "Early", startDay: 1, endDay: 4, status: .open)
        let closed = trip(title: "Closed", startDay: 3, endDay: 8, status: .closed)

        let sorted = TripStore.sortedOpenTrips([late, early, closed])

        #expect(sorted.map(\.title) == ["Early", "Late"])
    }

    @MainActor
    @Test("Closed trips sort by most recent window", .bug("https://github.com/heathdj/TripPlanner/issues/2"))
    func closedTripsSortByMostRecentWindow() {
        let older = trip(title: "Older", startDay: 1, endDay: 4, status: .closed)
        let newer = trip(title: "Newer", startDay: 10, endDay: 14, status: .closed)
        let open = trip(title: "Open", startDay: 20, endDay: 24, status: .open)

        let sorted = TripStore.sortedClosedTrips([older, newer, open])

        #expect(sorted.map(\.title) == ["Newer", "Older"])
    }

    @MainActor
    @Test("Exact start date plans a flexible trip", .bug("https://github.com/heathdj/TripPlanner/issues/49"))
    func exactStartDatePlansFlexibleTrip() throws {
        let trip = trip(title: "Plan me", startDay: 1, endDay: 10, status: .open)
        let exactEndDate = try TripLifecycleService.setExactStartDate(
            localDate(year: 2026, month: 5, day: 3),
            for: trip
        )

        #expect(trip.status == .planned)
        #expect(trip.exactStartDate == localDate(year: 2026, month: 5, day: 3))
        #expect(exactEndDate == localDate(year: 2026, month: 5, day: 4))
        #expect(trip.exactEndDate == localDate(year: 2026, month: 5, day: 4))
        #expect(trip.summary().startDateSummary == trip.exactDateDisplayString)
    }

    @MainActor
    @Test("Exact start date must fit inside the flexible window", .bug("https://github.com/heathdj/TripPlanner/issues/49"))
    func exactStartDateMustFitInsideFlexibleWindow() {
        let outsideWindowTrip = trip(title: "Outside window", startDay: 1, endDay: 4, status: .open)
        let tooLateTrip = trip(title: "Too late", startDay: 1, endDay: 4, status: .open)
        tooLateTrip.updateDuration(days: 3)

        #expect(throws: TripLifecycleService.ValidationError.startDateOutsideWindow) {
            try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 4, day: 29), for: outsideWindowTrip)
        }

        #expect(throws: TripLifecycleService.ValidationError.tripDoesNotFitWindow) {
            try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 5, day: 3), for: tooLateTrip)
        }

        #expect(outsideWindowTrip.status == .open)
        #expect(outsideWindowTrip.exactStartDate == nil)
        #expect(tooLateTrip.status == .open)
        #expect(tooLateTrip.exactStartDate == nil)
    }

    @MainActor
    @Test("Exact start dates include the last fitting day in the flexible window", .bug("https://github.com/heathdj/TripPlanner/issues/53"))
    func exactStartDatesIncludeLastFittingDayInWindow() throws {
        let boundaryTrip = Trip(
            title: "Boundary",
            location: "Test",
            windowStartDate: localDate(year: 2026, month: 5, day: 1),
            windowEndDate: localDate(year: 2026, month: 5, day: 4),
            durationDays: 3
        )

        let exactEndDate = try TripLifecycleService.setExactStartDate(
            localDate(year: 2026, month: 5, day: 2),
            for: boundaryTrip
        )

        #expect(exactEndDate == localDate(year: 2026, month: 5, day: 4))
        #expect(boundaryTrip.status == .planned)

        let tooLateTrip = Trip(
            title: "Too late boundary",
            location: "Test",
            windowStartDate: localDate(year: 2026, month: 5, day: 1),
            windowEndDate: localDate(year: 2026, month: 5, day: 4),
            durationDays: 3
        )
        #expect(throws: TripLifecycleService.ValidationError.tripDoesNotFitWindow) {
            try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 5, day: 3), for: tooLateTrip)
        }
    }

    @MainActor
    @Test("Clearing an exact date moves planned trips back to open", .bug("https://github.com/heathdj/TripPlanner/issues/49"))
    func clearingExactDateMovesPlannedTripBackToOpen() throws {
        let trip = trip(title: "Flexible again", startDay: 1, endDay: 8, status: .open)
        try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 5, day: 2), for: trip)

        try TripLifecycleService.clearExactStartDate(for: trip)

        #expect(trip.status == .open)
        #expect(trip.exactStartDate == nil)
    }

    @MainActor
    @Test("Lifecycle transitions reject invalid states", .bug("https://github.com/heathdj/TripPlanner/issues/53"))
    func lifecycleTransitionsRejectInvalidStates() throws {
        let openTrip = trip(title: "Open", startDay: 1, endDay: 8, status: .open)
        let activeTrip = trip(title: "Active", startDay: 1, endDay: 8, status: .open)
        let closedTrip = trip(title: "Closed", startDay: 1, endDay: 8, status: .closed)

        try TripLifecycleService.activate(activeTrip, at: localDate(year: 2026, month: 5, day: 1))

        #expect(throws: TripLifecycleService.ValidationError.cannotClearExactDate) {
            try TripLifecycleService.clearExactStartDate(for: openTrip)
        }
        #expect(throws: TripLifecycleService.ValidationError.cannotClearExactDate) {
            try TripLifecycleService.clearExactStartDate(for: activeTrip)
        }
        #expect(throws: TripLifecycleService.ValidationError.cannotClose) {
            try TripLifecycleService.close(closedTrip, outcome: .completed)
        }
    }

    @MainActor
    @Test("Active and closed transitions require explicit service calls", .bug("https://github.com/heathdj/TripPlanner/issues/50"))
    func activeAndClosedTransitionsRequireExplicitServiceCalls() throws {
        let activeTrip = trip(title: "Active one", startDay: 1, endDay: 8, status: .open)
        let secondActiveTrip = trip(title: "Active two", startDay: 3, endDay: 10, status: .open)
        let activationDate = localDate(year: 2026, month: 5, day: 1)
        let secondActivationDate = localDate(year: 2026, month: 5, day: 3)
        let closeDate = localDate(year: 2026, month: 5, day: 6)

        try TripLifecycleService.activate(activeTrip, at: activationDate)
        try TripLifecycleService.activate(secondActiveTrip, at: secondActivationDate)
        try TripLifecycleService.close(activeTrip, outcome: .cancelled, at: closeDate)

        #expect(activeTrip.status == .closed)
        #expect(activeTrip.exactStartDate == activationDate)
        #expect(activeTrip.activatedAt == activationDate)
        #expect(activeTrip.closedAt == closeDate)
        #expect(activeTrip.closedOutcome == .cancelled)
        #expect(activeTrip.effectiveClosedOutcome == .cancelled)
        #expect(activeTrip.summary().closedOutcomeSummary == "Cancelled")
        #expect(secondActiveTrip.status == .active)
        #expect(secondActiveTrip.exactStartDate == secondActivationDate)
        #expect(throws: TripLifecycleService.ValidationError.cannotActivate) {
            try TripLifecycleService.activate(activeTrip)
        }
    }

    @MainActor
    @Test("Undated activation must fit the flexible window", .bug("https://github.com/heathdj/TripPlanner/issues/50"))
    func undatedActivationMustFitFlexibleWindow() {
        let trip = trip(title: "Not today", startDay: 1, endDay: 4, status: .open)

        #expect(throws: TripLifecycleService.ValidationError.startDateOutsideWindow) {
            try TripLifecycleService.activate(trip, at: localDate(year: 2026, month: 4, day: 29))
        }

        #expect(trip.status == .open)
        #expect(trip.exactStartDate == nil)
        #expect(trip.activatedAt == nil)
    }

    @MainActor
    @Test("Activation date prompts use lead time and trip dates", .bug("https://github.com/heathdj/TripPlanner/issues/51"))
    func activationDatePromptsUseLeadTimeAndTripDates() throws {
        let trip = trip(title: "Scheduled", startDay: 10, endDay: 20, status: .open)
        try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 5, day: 10), for: trip)
        trip.updateDuration(days: 3)

        #expect(ActivationPromptEligibilityService.isDateEligible(
            trip,
            now: localDate(year: 2026, month: 5, day: 8),
            leadTimeDays: 2,
            isEnabled: true,
            timeZone: .current
        ))
        #expect(ActivationPromptEligibilityService.isDateEligible(
            trip,
            now: localDate(year: 2026, month: 5, day: 12),
            leadTimeDays: 0,
            isEnabled: true,
            timeZone: .current
        ))
        #expect(ActivationPromptEligibilityService.isDateEligible(
            trip,
            now: localDate(year: 2026, month: 5, day: 7),
            leadTimeDays: 2,
            isEnabled: true,
            timeZone: .current
        ) == false)
        #expect(ActivationPromptEligibilityService.isDateEligible(
            trip,
            now: localDate(year: 2026, month: 5, day: 8),
            leadTimeDays: 2,
            isEnabled: false,
            timeZone: .current
        ) == false)
    }

    @MainActor
    @Test("Activation date prompts use the destination time zone", .bug("https://github.com/heathdj/TripPlanner/issues/51"))
    func activationDatePromptsUseDestinationTimeZone() throws {
        let timeZone = try #require(TimeZone(identifier: "Pacific/Kiritimati"))
        let trip = trip(title: "Time zone", startDay: 10, endDay: 20, status: .open)
        try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 5, day: 10), for: trip)

        let calendarDayInDestination = date(year: 2026, month: 5, day: 9, hour: 11, timeZone: TimeZone(secondsFromGMT: 0) ?? .current)

        #expect(ActivationPromptEligibilityService.isDateEligible(
            trip,
            now: calendarDayInDestination,
            leadTimeDays: 0,
            isEnabled: true,
            timeZone: timeZone
        ))
        #expect(ActivationPromptEligibilityService.isDateEligible(
            trip,
            now: calendarDayInDestination,
            leadTimeDays: 0,
            isEnabled: true,
            timeZone: TimeZone(secondsFromGMT: 0) ?? .current
        ) == false)
    }

    @MainActor
    @Test("Activation proximity prompts use near you radius", .bug("https://github.com/heathdj/TripPlanner/issues/51"))
    func activationProximityPromptsUseNearYouRadius() {
        let userLocation = CLLocation(latitude: 41.8781, longitude: -87.6298)
        let nearby = trip(title: "Nearby", startDay: 1, endDay: 4, status: .open, latitude: 41.8818, longitude: -87.6231)
        let far = trip(title: "Far", startDay: 1, endDay: 4, status: .open, latitude: 40.7128, longitude: -74.0060)

        #expect(ActivationPromptEligibilityService.proximityDistance(
            for: nearby,
            userLocation: userLocation,
            nearYouDistanceKilometers: 10,
            isEnabled: true
        ) != nil)
        #expect(ActivationPromptEligibilityService.proximityDistance(
            for: far,
            userLocation: userLocation,
            nearYouDistanceKilometers: 10,
            isEnabled: true
        ) == nil)
        #expect(ActivationPromptEligibilityService.proximityDistance(
            for: nearby,
            userLocation: userLocation,
            nearYouDistanceKilometers: 10,
            isEnabled: false
        ) == nil)
    }

    @MainActor
    @Test("Activation prompts honor cooldown and suppression", .bug("https://github.com/heathdj/TripPlanner/issues/51"))
    func activationPromptsHonorCooldownAndSuppression() throws {
        let trip = trip(title: "Prompt state", startDay: 10, endDay: 20, status: .open)
        try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 5, day: 10), for: trip)
        let now = localDate(year: 2026, month: 5, day: 8)
        let dismissed = ActivationPromptEligibilityService.dismiss(
            tripID: trip.id,
            reasons: [.date],
            at: now,
            cooldownHours: 24,
            in: ActivationPromptState()
        )

        #expect(ActivationPromptEligibilityService.candidate(
            for: trip,
            now: localDate(year: 2026, month: 5, day: 8),
            userLocation: nil,
            nearYouDistanceKilometers: 100,
            leadTimeDays: 2,
            datePromptsEnabled: true,
            proximityPromptsEnabled: true,
            state: dismissed
        ) == nil)

        let suppressed = ActivationPromptEligibilityService.suppress(
            tripID: trip.id,
            reasons: [.date],
            at: now,
            in: dismissed
        )
        #expect(ActivationPromptEligibilityService.isSuppressed(tripID: trip.id, in: suppressed))

        let reset = ActivationPromptEligibilityService.resetSuppression(tripID: trip.id, in: suppressed)
        #expect(ActivationPromptEligibilityService.isSuppressed(tripID: trip.id, in: reset) == false)
    }

    @MainActor
    @Test("Combined date and proximity eligibility produces one prompt", .bug("https://github.com/heathdj/TripPlanner/issues/51"))
    func combinedEligibilityProducesOnePrompt() throws {
        let userLocation = CLLocation(latitude: 41.8781, longitude: -87.6298)
        let trip = trip(
            title: "Combined",
            startDay: 10,
            endDay: 20,
            status: .open,
            latitude: 41.8818,
            longitude: -87.6231
        )
        try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 5, day: 10), for: trip)

        let candidate = try #require(ActivationPromptEligibilityService.candidate(
            for: trip,
            now: localDate(year: 2026, month: 5, day: 8),
            userLocation: userLocation,
            nearYouDistanceKilometers: 100,
            leadTimeDays: 2,
            datePromptsEnabled: true,
            proximityPromptsEnabled: true,
            state: ActivationPromptState()
        ))

        #expect(candidate.trip.id == trip.id)
        #expect(candidate.reasons == [.date, .proximity])
    }

    @MainActor
    @Test("Activation prompt state persists through AppStorage encoding", .bug("https://github.com/heathdj/TripPlanner/issues/53"))
    func activationPromptStatePersistsThroughAppStorageEncoding() {
        let tripID = UUID()
        let shownAt = localDate(year: 2026, month: 5, day: 6)
        let shownState = ActivationPromptEligibilityService.recordPromptShown(
            for: tripID,
            reasons: [.date, .proximity],
            at: shownAt,
            in: ActivationPromptState()
        )
        let state = ActivationPromptEligibilityService.suppress(
            tripID: tripID,
            reasons: [.date, .proximity],
            at: shownAt,
            in: shownState
        )

        let encoded = TravelPreferencesStorage.encodeActivationPromptState(state)
        let decoded = TravelPreferencesStorage.decodeActivationPromptState(from: encoded)
        let record = decoded.record(for: tripID)

        #expect(record.isSuppressed)
        #expect(record.lastPromptReasons == [.date, .proximity])
        #expect(record.lastPromptedAt == shownAt)
        #expect(TravelPreferencesStorage.decodeActivationPromptState(from: "not json") == ActivationPromptState())
    }

    @MainActor
    @Test("Location failure leaves date prompts available", .bug("https://github.com/heathdj/TripPlanner/issues/53"))
    func locationFailureLeavesDatePromptsAvailable() throws {
        let trip = trip(title: "Date only", startDay: 10, endDay: 20, status: .open)
        try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 5, day: 10), for: trip)

        let candidate = try #require(ActivationPromptEligibilityService.candidate(
            for: trip,
            now: localDate(year: 2026, month: 5, day: 8),
            userLocation: nil,
            nearYouDistanceKilometers: 100,
            leadTimeDays: 2,
            datePromptsEnabled: true,
            proximityPromptsEnabled: true,
            state: ActivationPromptState()
        ))

        #expect(candidate.reasons == [.date])
        #expect(LocationServiceMessage.message(for: CLError(.locationUnknown)) == LocationServiceMessage.temporarilyUnavailable)
        #expect(LocationServiceMessage.message(for: NSError(domain: "TripPlannerTests", code: 1)) == LocationServiceMessage.unavailable)
        #expect(LocationServiceMessage.denied.contains("Open Settings"))
        #expect(LocationServiceMessage.restricted.contains("Open and Closed sections"))
    }

    @MainActor
    @Test("Migrated lifecycle values are normalized safely", .bug("https://github.com/heathdj/TripPlanner/issues/49"))
    func migratedLifecycleValuesAreNormalizedSafely() {
        let migratedPlanned = trip(title: "Migrated planned", startDay: 1, endDay: 8, status: .open)
        migratedPlanned.exactStartDate = localDate(year: 2026, month: 5, day: 2)
        let migratedOpen = trip(title: "Migrated open", startDay: 1, endDay: 8, status: .planned)
        let migratedClosed = trip(title: "Migrated closed", startDay: 1, endDay: 8, status: .closed)

        TripLifecycleService.normalizeMigratedLifecycle(for: migratedPlanned)
        TripLifecycleService.normalizeMigratedLifecycle(for: migratedOpen)
        TripLifecycleService.normalizeMigratedLifecycle(for: migratedClosed)

        #expect(migratedPlanned.status == .planned)
        #expect(migratedOpen.status == .open)
        #expect(migratedClosed.status == .closed)
        #expect(migratedClosed.closedOutcome == .completed)
    }

    @MainActor
    @Test("Travel settings default duration and window length", .bug("https://github.com/heathdj/TripPlanner/issues/2"))
    func travelSettingsDefaultsMatchIssueRequirements() {
        let settings = TravelSettings()

        #expect(settings.defaultDurationDays == 14)
        #expect(settings.defaultWindowLengthDays == 45)
        #expect(settings.distanceUnit == .kilometers)
        #expect(settings.nearYouDistanceKilometers == 100)

        settings.updateDefaultDuration(days: 0)
        settings.updateDefaultWindowLength(days: -4)
        settings.updateDistanceUnit(.miles)
        settings.updateNearYouDistance(value: 50, unit: .miles)

        #expect(settings.defaultDurationDays == 1)
        #expect(settings.defaultWindowLengthDays == 1)
        #expect(settings.distanceUnit == .miles)
        #expect(settings.nearYouDistanceKilometers == 50 * 1.609344)
    }

    @MainActor
    @Test("Travel settings manage reusable activity interests", .bug("https://github.com/heathdj/TripPlanner/issues/6"))
    func travelSettingsManageReusableActivityInterests() {
        let settings = TravelSettings()

        #expect(ActivityInterestCatalog.builtInInterests == [
            "Museums",
            "Hikes",
            "Live Events",
            "Local Food",
            "Architecture",
            "Beaches",
            "History",
            "Nightlife",
            "Shopping",
            "Photography"
        ])

        settings.toggleInterest("Museums")
        settings.toggleInterest("Local Food")
        settings.addCustomInterest(" pottery ")
        settings.addCustomInterest("Pottery")

        #expect(settings.isInterestSelected("museums"))
        #expect(settings.selectedInterestNames ?? [] == ["Museums", "Local Food", "pottery"])
        #expect(settings.customInterestNames ?? [] == ["pottery"])
        #expect(settings.visibleSelectedInterests == ["Museums", "Local Food", "pottery"])

        settings.toggleInterest("Museums")
        settings.removeCustomInterest("POTTERY")

        #expect(settings.isInterestSelected("Museums") == false)
        #expect(settings.selectedInterestNames ?? [] == ["Local Food"])
        #expect(settings.customInterestNames?.isEmpty ?? true)
    }

    @MainActor
    @Test("Trip generation prompt includes private planning inputs", .bug("https://github.com/heathdj/TripPlanner/issues/7"))
    func tripGenerationPromptIncludesPrivatePlanningInputs() {
        let input = TripPlanGenerationInput(
            destination: "Sydney, Australia",
            travelWindow: "Aug 1-Aug 15, 2026",
            durationDays: 4,
            travelerCount: 2,
            theme: "Harbor views and local food",
            selectedInterests: ["Museums", "Local Food"]
        )

        let prompt = FoundationModelsTripPlanGenerator.prompt(for: input)

        #expect(prompt.contains("Destination: Sydney, Australia"))
        #expect(prompt.contains("Flexible travel window: Aug 1-Aug 15, 2026"))
        #expect(prompt.contains("Trip duration: 4 days"))
        #expect(prompt.contains("Traveler count: 2"))
        #expect(prompt.contains("Trip theme: Harbor views and local food"))
        #expect(prompt.contains("Selected interests: Museums, Local Food"))
        #expect(prompt.contains("Use specific named places whenever possible"))
        #expect(prompt.contains("Include at least one specific named restaurant"))
        #expect(prompt.contains("Do not include reservations, prices, weather, hours, live schedules"))
    }

    @MainActor
    @Test("Generated trip drafts clamp days and preserve supported categories", .bug("https://github.com/heathdj/TripPlanner/issues/7"))
    func generatedTripDraftsClampDaysAndPreserveSupportedCategories() {
        let draft = TripPlanGenerationSanitizer.draft(
            title: "  ",
            overview: "",
            items: [
                TripPlanDraftItemInput(name: "Late dinner", notes: "Neighborhood suggestion", category: .food, dayNumber: 9),
                TripPlanDraftItemInput(name: "Arrival", notes: "Airport to hotel", category: .transit, dayNumber: 0),
                TripPlanDraftItemInput(name: "Gallery", notes: "Indoor option", category: .activity, dayNumber: 2),
                TripPlanDraftItemInput(name: "", notes: "", category: .stay, dayNumber: 1)
            ],
            durationDays: 3
        )

        #expect(draft.title == "Generated Trip Draft")
        #expect(draft.overview == "Review these on-device suggestions before saving anything to your trip.")
        #expect(draft.items.map(\.dayNumber) == [1, 2])
        #expect(draft.items.map(\.category) == [.transit, .activity])
        #expect(draft.items.map(\.name) == ["Arrival", "Gallery"])
    }

    @MainActor
    @Test("Generated trip drafts keep one departure event", .bug("https://github.com/heathdj/TripPlanner/issues/8"))
    func generatedTripDraftsKeepOneDepartureEvent() {
        let draft = TripPlanGenerationSanitizer.draft(
            title: "Lisbon",
            overview: "Draft",
            items: [
                TripPlanDraftItemInput(name: "Departure", notes: "Airport", category: .transit, dayNumber: 1),
                TripPlanDraftItemInput(name: "MAAT Museum", notes: "Indoor option", category: .activity, dayNumber: 2),
                TripPlanDraftItemInput(name: "Departure Event", notes: "Fly home", category: .transit, dayNumber: 4)
            ],
            durationDays: 4
        )

        #expect(draft.items.filter(\.isDepartureEvent).map(\.name) == ["Departure Event"])
        #expect(draft.items.map(\.name) == ["MAAT Museum", "Departure Event"])
    }

    @MainActor
    @Test("Generated trip drafts filter vague placeholders but keep named places", .bug("https://github.com/heathdj/TripPlanner/issues/59"))
    func generatedTripDraftsFilterVaguePlaceholdersButKeepNamedPlaces() {
        let draft = TripPlanGenerationSanitizer.draft(
            title: "Paris",
            overview: "Draft",
            items: [
                TripPlanDraftItemInput(name: "Visit a museum", notes: "Generic activity", category: .activity, dayNumber: 1),
                TripPlanDraftItemInput(name: "Visit the Louvre Museum", notes: "Review exact entrance details.", category: .activity, dayNumber: 1),
                TripPlanDraftItemInput(name: "Explore downtown", notes: "Too vague", category: .activity, dayNumber: 2),
                TripPlanDraftItemInput(name: "Go shopping", notes: "Too vague", category: .activity, dayNumber: 2),
                TripPlanDraftItemInput(name: "Shakespeare and Company", notes: "Named bookstore stop.", category: .activity, dayNumber: 3)
            ],
            durationDays: 3
        )

        #expect(draft.items.map(\.name) == ["Visit the Louvre Museum", "Shakespeare and Company"])
    }

    @MainActor
    @Test("Generated trip drafts allow only boundary arrival and departure placeholders", .bug("https://github.com/heathdj/TripPlanner/issues/59"))
    func generatedTripDraftsAllowOnlyBoundaryArrivalAndDeparturePlaceholders() {
        let draft = TripPlanGenerationSanitizer.draft(
            title: "Rome",
            overview: "Draft",
            items: [
                TripPlanDraftItemInput(name: "Arrival", notes: "Settle in.", category: .transit, dayNumber: 1),
                TripPlanDraftItemInput(name: "Arrival", notes: "Bad middle placeholder.", category: .transit, dayNumber: 2),
                TripPlanDraftItemInput(name: "Departure", notes: "Bad middle placeholder.", category: .transit, dayNumber: 2),
                TripPlanDraftItemInput(name: "Colosseum", notes: "Named landmark.", category: .activity, dayNumber: 2),
                TripPlanDraftItemInput(name: "Departure", notes: "Airport transfer.", category: .transit, dayNumber: 4)
            ],
            durationDays: 4
        )

        #expect(draft.items.map(\.name) == ["Arrival", "Colosseum", "Departure"])
        #expect(draft.items.map(\.dayNumber) == [1, 2, 4])
    }

    @MainActor
    @Test("Generated trip drafts require named restaurant items", .bug("https://github.com/heathdj/TripPlanner/issues/59"))
    func generatedTripDraftsRequireNamedRestaurantItems() {
        let draft = TripPlanGenerationSanitizer.draft(
            title: "Austin",
            overview: "Draft",
            items: [
                TripPlanDraftItemInput(name: "Have lunch", notes: "Generic meal", category: .food, dayNumber: 1),
                TripPlanDraftItemInput(name: "Eat at a restaurant", notes: "Generic meal", category: .food, dayNumber: 1),
                TripPlanDraftItemInput(name: "Lunch at Franklin Barbecue", notes: "Named meal phrasing.", category: .food, dayNumber: 2),
                TripPlanDraftItemInput(name: "Franklin Barbecue", notes: "Named restaurant candidate.", category: .food, dayNumber: 2),
                TripPlanDraftItemInput(name: "Veracruz All Natural", notes: "Named restaurant candidate.", category: .food, dayNumber: 3)
            ],
            durationDays: 3
        )

        #expect(draft.items.map(\.name) == ["Franklin Barbecue", "Lunch at Franklin Barbecue", "Veracruz All Natural"])
        #expect(draft.items.allSatisfy { $0.category == .food })
    }

    @MainActor
    @Test("Generated trip drafts strip unsafe live details from notes", .bug("https://github.com/heathdj/TripPlanner/issues/59"))
    func generatedTripDraftsStripUnsafeLiveDetailsFromNotes() {
        let draft = TripPlanGenerationSanitizer.draft(
            title: "Sydney",
            overview: "Draft",
            items: [
                TripPlanDraftItemInput(name: "Sydney Opera House", notes: "Opens at 9 AM and tickets are $45.", category: .activity, dayNumber: 1),
                TripPlanDraftItemInput(name: "Museum of Contemporary Art Australia", notes: "Circular Quay area.", category: .activity, dayNumber: 2),
                TripPlanDraftItemInput(name: "Bennelong", notes: "1 Bennelong Point, Sydney.", category: .food, dayNumber: 2)
            ],
            durationDays: 2
        )

        #expect(draft.items.map(\.name) == ["Sydney Opera House", "Bennelong", "Museum of Contemporary Art Australia"])
        #expect(draft.items[0].notesOrAddress.isEmpty)
        #expect(draft.items[1].notesOrAddress.isEmpty)
        #expect(draft.items[2].notesOrAddress == "Circular Quay area.")
    }

    @MainActor
    @Test("Generated trip drafts block malformed generic output from save path", .bug("https://github.com/heathdj/TripPlanner/issues/59"))
    func generatedTripDraftsBlockMalformedGenericOutputFromSavePath() {
        let draft = TripPlanGenerationSanitizer.draft(
            title: "Malformed",
            overview: "Draft",
            items: [
                TripPlanDraftItemInput(name: "", notes: "Blank", category: .activity, dayNumber: 1),
                TripPlanDraftItemInput(name: "Trip idea", notes: "Fallback-style placeholder", category: .activity, dayNumber: 1),
                TripPlanDraftItemInput(name: "Have dinner", notes: "Generic meal", category: .food, dayNumber: 2)
            ],
            durationDays: 2
        )

        #expect(draft.items.isEmpty)
    }

    @MainActor
    @Test("Generated itinerary items unresolved by place search are marked for review", .bug("https://github.com/heathdj/TripPlanner/issues/59"))
    func generatedItineraryItemsUnresolvedByPlaceSearchAreMarkedForReview() {
        let unresolved = ItineraryItem(
            name: "Louvre Museum",
            notesOrAddress: "Confirm the exact entrance.",
            category: .activity,
            dayNumber: 2
        )
        let resolved = ItineraryItem(
            name: "Colosseum",
            category: .activity,
            dayNumber: 2,
            latitude: 41.8902,
            longitude: 12.4922
        )
        let boundary = ItineraryItem(
            name: "Departure",
            category: .transit,
            dayNumber: 4
        )

        let reviewItem = GeneratedItineraryPlaceReviewPolicy.itemForReview(unresolved, durationDays: 4)
        let exactItem = GeneratedItineraryPlaceReviewPolicy.itemForReview(resolved, durationDays: 4)
        let boundaryItem = GeneratedItineraryPlaceReviewPolicy.itemForReview(boundary, durationDays: 4)

        #expect(reviewItem.notesOrAddress.contains(GeneratedItineraryPlaceReviewPolicy.unresolvedPlaceReviewNote))
        #expect(exactItem.notesOrAddress.isEmpty)
        #expect(boundaryItem.notesOrAddress.isEmpty)
    }

    @MainActor
    @Test("Nearby grouping promotes planned and open trips inside the radius", .bug("https://github.com/heathdj/TripPlanner/issues/50"))
    func nearbyGroupingPromotesPlannedAndOpenTripsInsideRadius() throws {
        let userLocation = CLLocation(latitude: 41.8781, longitude: -87.6298)
        let nearbyOpen = trip(
            title: "Nearby",
            startDay: 1,
            endDay: 2,
            status: .open,
            latitude: 41.8818,
            longitude: -87.6231
        )
        let farOpen = trip(
            title: "Far",
            startDay: 3,
            endDay: 4,
            status: .open,
            latitude: 40.7128,
            longitude: -74.0060
        )
        let nearbyPlanned = trip(
            title: "Nearby Planned",
            startDay: 7,
            endDay: 12,
            status: .open,
            latitude: 41.8818,
            longitude: -87.6231
        )
        try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 5, day: 8), for: nearbyPlanned)
        let nearbyActive = trip(
            title: "Nearby Active",
            startDay: 10,
            endDay: 15,
            status: .open,
            latitude: 41.8818,
            longitude: -87.6231
        )
        try TripLifecycleService.activate(nearbyActive, at: localDate(year: 2026, month: 5, day: 10))
        let nearbyClosed = trip(
            title: "Closed nearby",
            startDay: 5,
            endDay: 6,
            status: .closed,
            latitude: 41.8818,
            longitude: -87.6231
        )

        let groups = TripStore.groupedTrips(
            [farOpen, nearbyClosed, nearbyPlanned, nearbyActive, nearbyOpen],
            userLocation: userLocation,
            nearYouDistanceKilometers: 100
        )

        #expect(groups.nearbyTrips.map(\.trip.title) == ["Nearby", "Nearby Planned"])
        #expect(groups.openTrips.map(\.title) == ["Far"])
        #expect(groups.plannedTrips.isEmpty)
        #expect(groups.activeTrips.map(\.title) == ["Nearby Active"])
        #expect(groups.closedTrips.map(\.title) == ["Closed nearby"])
    }

    @MainActor
    @Test("Grouping without location keeps lifecycle sections visible", .bug("https://github.com/heathdj/TripPlanner/issues/49"))
    func groupingWithoutLocationKeepsLifecycleSectionsVisible() throws {
        let open = trip(
            title: "Open",
            startDay: 1,
            endDay: 2,
            status: .open,
            latitude: 41.8818,
            longitude: -87.6231
        )
        let planned = trip(title: "Planned", startDay: 5, endDay: 8, status: .open)
        try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 5, day: 5), for: planned)
        let active = trip(title: "Active", startDay: 9, endDay: 12, status: .open)
        try TripLifecycleService.activate(active, at: localDate(year: 2026, month: 5, day: 9))
        let closed = trip(title: "Closed", startDay: 3, endDay: 4, status: .closed)

        let groups = TripStore.groupedTrips(
            [closed, active, planned, open],
            userLocation: nil,
            nearYouDistanceKilometers: 100
        )

        #expect(groups.nearbyTrips.isEmpty)
        #expect(groups.openTrips.map(\.title) == ["Open"])
        #expect(groups.plannedTrips.map(\.title) == ["Planned"])
        #expect(groups.activeTrips.map(\.title) == ["Active"])
        #expect(groups.closedTrips.map(\.title) == ["Closed"])
    }

    @MainActor
    @Test("Active trip launch sorting prioritizes current trips and start dates", .bug("https://github.com/heathdj/TripPlanner/issues/52"))
    func activeTripLaunchSortingPrioritizesCurrentTripsAndStartDates() throws {
        let currentLaterTitle = trip(title: "Zoo", startDay: 10, endDay: 14, status: .open)
        let currentEarlierTitle = trip(title: "Aquarium", startDay: 10, endDay: 14, status: .open)
        let olderActive = trip(title: "Older", startDay: 1, endDay: 5, status: .open)
        let planned = trip(title: "Planned", startDay: 8, endDay: 12, status: .open)
        let currentDate = localDate(year: 2026, month: 5, day: 10)

        try TripLifecycleService.activate(olderActive, at: localDate(year: 2026, month: 5, day: 1))
        try TripLifecycleService.activate(currentLaterTitle, at: currentDate)
        try TripLifecycleService.activate(currentEarlierTitle, at: currentDate)
        try TripLifecycleService.setExactStartDate(localDate(year: 2026, month: 5, day: 8), for: planned)

        let sortedTrips = TripStore.sortedLaunchActiveTrips(
            [currentLaterTitle, planned, olderActive, currentEarlierTitle],
            on: currentDate
        )

        #expect(sortedTrips.map(\.title) == ["Aquarium", "Zoo", "Older"])
    }

    @MainActor
    @Test("Active trip launch decisions are once per unblocked startup", .bug("https://github.com/heathdj/TripPlanner/issues/52"))
    func activeTripLaunchDecisionsAreOncePerUnblockedStartup() throws {
        let firstActive = trip(title: "First", startDay: 1, endDay: 6, status: .open)
        let secondActive = trip(title: "Second", startDay: 3, endDay: 8, status: .open)
        let open = trip(title: "Open", startDay: 4, endDay: 9, status: .open)
        let currentDate = localDate(year: 2026, month: 5, day: 3)

        try TripLifecycleService.activate(firstActive, at: localDate(year: 2026, month: 5, day: 1))
        try TripLifecycleService.activate(secondActive, at: currentDate)

        #expect(
            TripStore.activeLaunchDecision(
                for: [firstActive, open],
                hasAlreadyPresented: false,
                hasBlockingPresentation: false,
                on: currentDate
            ) == .single(firstActive.id)
        )
        #expect(
            TripStore.activeLaunchDecision(
                for: [secondActive, firstActive, open],
                hasAlreadyPresented: false,
                hasBlockingPresentation: false,
                on: currentDate
            ) == .chooser([secondActive.id, firstActive.id])
        )
        #expect(
            TripStore.activeLaunchDecision(
                for: [firstActive],
                hasAlreadyPresented: true,
                hasBlockingPresentation: false,
                on: currentDate
            ) == .none
        )
        #expect(
            TripStore.activeLaunchDecision(
                for: [firstActive],
                hasAlreadyPresented: false,
                hasBlockingPresentation: true,
                on: currentDate
            ) == .none
        )
        #expect(
            TripStore.activeLaunchDecision(
                for: [open],
                hasAlreadyPresented: false,
                hasBlockingPresentation: false,
                on: currentDate
            ) == .none
        )
    }

    @MainActor
    @Test("Active trip launch decisions handle zero one and many active trips", .bug("https://github.com/heathdj/TripPlanner/issues/53"))
    func activeTripLaunchDecisionsHandleZeroOneAndManyActiveTrips() throws {
        let open = trip(title: "Open", startDay: 1, endDay: 8, status: .open)
        let firstActive = trip(title: "First", startDay: 1, endDay: 8, status: .open)
        let secondActive = trip(title: "Second", startDay: 2, endDay: 9, status: .open)
        let currentDate = localDate(year: 2026, month: 5, day: 2)

        try TripLifecycleService.activate(firstActive, at: localDate(year: 2026, month: 5, day: 1))
        try TripLifecycleService.activate(secondActive, at: currentDate)

        #expect(TripStore.activeLaunchDecision(
            for: [],
            hasAlreadyPresented: false,
            hasBlockingPresentation: false,
            on: currentDate
        ) == .none)
        #expect(TripStore.activeLaunchDecision(
            for: [open],
            hasAlreadyPresented: false,
            hasBlockingPresentation: false,
            on: currentDate
        ) == .none)
        #expect(TripStore.activeLaunchDecision(
            for: [open, firstActive],
            hasAlreadyPresented: false,
            hasBlockingPresentation: false,
            on: currentDate
        ) == .single(firstActive.id))
        #expect(TripStore.activeLaunchDecision(
            for: [open, secondActive, firstActive],
            hasAlreadyPresented: false,
            hasBlockingPresentation: false,
            on: currentDate
        ) == .chooser([firstActive.id, secondActive.id]))
    }

    @MainActor
    @Test("Trip data and reviewed plans persist through SwiftData", .bug("https://github.com/heathdj/TripPlanner/issues/2"))
    func tripsSettingsAndReviewedPlansPersist() throws {
        let storeURL = temporaryStoreURL()
        try removeStore(at: storeURL)
        defer { try? removeStore(at: storeURL) }

        let firstContainer = try makeContainer(at: storeURL)
        let firstContext = ModelContext(firstContainer)
        let trip = Trip(
            title: "Persisted Trip",
            location: "Santa Fe",
            windowStartDate: date(year: 2026, month: 3, day: 1),
            windowEndDate: date(year: 2026, month: 3, day: 15),
            durationDays: 4,
            status: .closed,
            highlight: "Local food and museum mornings.",
            plannedItemCount: 6,
            completedItemCount: 2,
            travelerCount: 3,
            itineraryItems: [
                ItineraryItem(
                    name: "Museum morning",
                    category: .activity,
                    dayNumber: 1,
                    completionState: .completed,
                    completedAt: localDate(year: 2026, month: 3, day: 6)
                ),
                ItineraryItem(
                    name: "Dinner reservation",
                    category: .food,
                    dayNumber: 2,
                    completionState: .skipped
                )
            ],
            exactStartDate: localDate(year: 2026, month: 3, day: 5),
            activatedAt: localDate(year: 2026, month: 3, day: 5),
            closedAt: localDate(year: 2026, month: 3, day: 9),
            closedOutcome: .completed
        )
        let settings = TravelSettings(defaultDurationDays: 14, defaultWindowLengthDays: 45)
        let reviewedPlan = ReviewedTripPlan(
            tripID: trip.id,
            title: "Reviewed Santa Fe plan",
            notes: "Reviewed and ready to save."
        )

        firstContext.insert(trip)
        firstContext.insert(settings)
        firstContext.insert(reviewedPlan)
        try firstContext.save()

        let secondContainer = try makeContainer(at: storeURL)
        let secondContext = ModelContext(secondContainer)
        let persistedTrips = try secondContext.fetch(FetchDescriptor<Trip>())
        let persistedSettings = try secondContext.fetch(FetchDescriptor<TravelSettings>())
        let persistedPlans = try secondContext.fetch(FetchDescriptor<ReviewedTripPlan>())

        let persistedTrip = try #require(persistedTrips.first)
        let persistedSetting = try #require(persistedSettings.first)
        let persistedPlan = try #require(persistedPlans.first)

        #expect(persistedTrip.title == "Persisted Trip")
        #expect(persistedTrip.windowLengthDays == 15)
        #expect(persistedTrip.durationDays == 4)
        #expect(persistedTrip.validStartDateCount == 12)
        #expect(persistedTrip.status == .closed)
        #expect(persistedTrip.exactStartDate == localDate(year: 2026, month: 3, day: 5))
        #expect(persistedTrip.exactEndDate == localDate(year: 2026, month: 3, day: 8))
        #expect(persistedTrip.activatedAt == localDate(year: 2026, month: 3, day: 5))
        #expect(persistedTrip.closedAt == localDate(year: 2026, month: 3, day: 9))
        #expect(persistedTrip.closedOutcome == .completed)
        #expect(persistedTrip.completedItemCount == 2)
        #expect(persistedTrip.travelerDisplayString == "3 travelers")
        #expect(persistedTrip.itineraryItems.map(\.name) == ["Museum morning", "Dinner reservation"])
        #expect(persistedTrip.itineraryItems.map(\.category) == [.activity, .food])
        #expect(persistedTrip.itineraryItems.map(\.completionState) == [.completed, .skipped])
        #expect(persistedTrip.itineraryItems.first?.completedAt == localDate(year: 2026, month: 3, day: 6))
        #expect(persistedTrip.progressDisplayString == "1 of 2 done")
        #expect(persistedSetting.defaultDurationDays == 14)
        #expect(persistedSetting.defaultWindowLengthDays == 45)
        #expect(persistedSetting.distanceUnit == .kilometers)
        #expect(persistedSetting.nearYouDistanceKilometers == 100)
        #expect(persistedPlan.tripID == persistedTrip.id)
        #expect(persistedPlan.title == "Reviewed Santa Fe plan")
    }

    @MainActor
    @Test("Custom interests persist through SwiftData", .bug("https://github.com/heathdj/TripPlanner/issues/6"))
    func customInterestsPersistThroughSwiftData() throws {
        let storeURL = temporaryStoreURL()
        try removeStore(at: storeURL)
        defer { try? removeStore(at: storeURL) }

        let firstContainer = try makeContainer(at: storeURL)
        let firstContext = ModelContext(firstContainer)
        let settings = TravelSettings()
        settings.toggleInterest("Hikes")
        settings.addCustomInterest("Gardens")
        settings.addCustomInterest("Jazz Clubs")

        firstContext.insert(settings)
        try firstContext.save()

        let secondContainer = try makeContainer(at: storeURL)
        let secondContext = ModelContext(secondContainer)
        let persistedSettings = try secondContext.fetch(FetchDescriptor<TravelSettings>())
        let persistedSetting = try #require(persistedSettings.first)

        #expect(persistedSetting.selectedInterestNames ?? [] == ["Hikes", "Gardens", "Jazz Clubs"])
        #expect(persistedSetting.customInterestNames ?? [] == ["Gardens", "Jazz Clubs"])
        #expect(persistedSetting.visibleSelectedInterests == ["Hikes", "Gardens", "Jazz Clubs"])
    }

    @Test("Travel preferences encode and mutate selected interests")
    func travelPreferencesEncodeAndMutateSelectedInterests() {
        let encoded = TravelPreferencesStorage.encodeInterests([
            " Museums ",
            "museums",
            "Local Food",
            ""
        ])

        #expect(TravelPreferencesStorage.decodeInterests(from: encoded) == ["Museums", "Local Food"])
        #expect(TravelPreferencesStorage.decodeInterests(from: "not json") == [])

        let selectedMuseums = TravelPreferencesStorage.toggledInterest("Museums", selected: [])
        #expect(selectedMuseums == ["Museums"])
        #expect(TravelPreferencesStorage.toggledInterest("museums", selected: selectedMuseums).isEmpty)

        let updated = TravelPreferencesStorage.addingCustomInterest(
            " Gardens ",
            selected: selectedMuseums,
            custom: []
        )

        #expect(updated.selected == ["Museums", "Gardens"])
        #expect(updated.custom == ["Gardens"])
        #expect(
            TravelPreferencesStorage.visibleSelectedInterests(
                selected: updated.selected,
                custom: updated.custom
            ) == ["Museums", "Gardens"]
        )

        let removed = TravelPreferencesStorage.removingCustomInterest(
            "gardens",
            selected: updated.selected,
            custom: updated.custom
        )

        #expect(removed.selected == ["Museums"])
        #expect(removed.custom.isEmpty)
    }

    @MainActor
    @Test("Travel settings store reuses the persisted settings row")
    func travelSettingsStoreReusesPersistedSettingsRow() throws {
        let storeURL = temporaryStoreURL()
        try removeStore(at: storeURL)
        defer { try? removeStore(at: storeURL) }

        let firstContainer = try makeContainer(at: storeURL)
        let firstContext = ModelContext(firstContainer)
        let settings = try TravelSettingsStore.settings(in: firstContext)
        settings.updateDefaultDuration(days: 9)
        settings.updateDefaultWindowLength(days: 21)
        settings.toggleInterest("Museums")
        try firstContext.save()

        let sameSettings = try TravelSettingsStore.settings(in: firstContext)

        #expect(sameSettings.id == settings.id)

        let secondContainer = try makeContainer(at: storeURL)
        let secondContext = ModelContext(secondContainer)
        let persistedSettings = try secondContext.fetch(FetchDescriptor<TravelSettings>())
        let persistedSetting = try #require(persistedSettings.first)

        #expect(persistedSettings.count == 1)
        #expect(persistedSetting.defaultDurationDays == 9)
        #expect(persistedSetting.defaultWindowLengthDays == 21)
        #expect(persistedSetting.visibleSelectedInterests == ["Museums"])
    }

    @MainActor
    @Test("Reviewed plan save sorts items and replaces existing plans", .bug("https://github.com/heathdj/TripPlanner/issues/8"))
    func reviewedPlanSaveSortsItemsAndReplacesExistingPlans() throws {
        let storeURL = temporaryStoreURL()
        try removeStore(at: storeURL)
        defer { try? removeStore(at: storeURL) }

        let firstContainer = try makeContainer(at: storeURL)
        let firstContext = ModelContext(firstContainer)
        let trip = Trip(
            title: "Reviewed",
            location: "Lisbon",
            windowStartDate: date(year: 2026, month: 9, day: 1),
            windowEndDate: date(year: 2026, month: 9, day: 8),
            durationDays: 4,
            itineraryItems: [
                ItineraryItem(name: "Old item", category: .activity, dayNumber: 1)
            ]
        )
        let oldPlan = ReviewedTripPlan(
            tripID: trip.id,
            title: "Old plan",
            notes: "Replace me"
        )

        firstContext.insert(trip)
        firstContext.insert(oldPlan)
        try firstContext.save()

        let reviewedPlan = try ReviewedTripPlanStore.saveReviewedPlan(
            title: "  Lisbon food weekend  ",
            overview: "  Reviewed and ready.  ",
            items: [
                ItineraryItem(name: "Dinner", notesOrAddress: "Bairro Alto", category: .food, dayNumber: 2),
                ItineraryItem(name: " Arrival ", notesOrAddress: "Airport to hotel", category: .transit, dayNumber: 1),
                ItineraryItem(name: "", notesOrAddress: "Drop blank item", category: .activity, dayNumber: 1),
                ItineraryItem(name: "Brunch", notesOrAddress: "Search by area", category: .food, dayNumber: 2)
            ],
            for: trip,
            in: firstContext
        )

        #expect(reviewedPlan.title == "Lisbon food weekend")
        #expect(reviewedPlan.notes == "Reviewed and ready.")
        #expect(trip.itineraryItems.map(\.name) == ["Arrival", "Brunch", "Dinner"])
        #expect(trip.itineraryItems.map(\.dayNumber) == [1, 2, 2])
        #expect(trip.plannedItemCount == 3)
        #expect(trip.completedItemCount == 0)

        let secondContainer = try makeContainer(at: storeURL)
        let secondContext = ModelContext(secondContainer)
        let persistedTrips = try secondContext.fetch(FetchDescriptor<Trip>())
        let persistedPlans = try secondContext.fetch(FetchDescriptor<ReviewedTripPlan>())
        let persistedTrip = try #require(persistedTrips.first)
        let persistedPlan = try #require(persistedPlans.first)

        #expect(persistedPlans.count == 1)
        #expect(persistedPlan.title == "Lisbon food weekend")
        #expect(persistedTrip.itineraryItems.map(\.name) == ["Arrival", "Brunch", "Dinner"])
        #expect(persistedTrip.itineraryItems[1].searchableDestination(in: persistedTrip) == "Brunch, Search by area, Lisbon")
    }

    @MainActor
    @Test("Reviewed plan save keeps one departure event", .bug("https://github.com/heathdj/TripPlanner/issues/8"))
    func reviewedPlanSaveKeepsOneDepartureEvent() throws {
        let storeURL = temporaryStoreURL()
        try removeStore(at: storeURL)
        defer { try? removeStore(at: storeURL) }

        let container = try makeContainer(at: storeURL)
        let context = ModelContext(container)
        let trip = Trip(
            title: "Departure",
            location: "Test",
            windowStartDate: date(year: 2026, month: 11, day: 1),
            windowEndDate: date(year: 2026, month: 11, day: 4),
            durationDays: 4
        )
        context.insert(trip)

        _ = try ReviewedTripPlanStore.saveReviewedPlan(
            title: "Reviewed",
            overview: "Overview",
            items: [
                ItineraryItem(name: "Departure", category: .transit, dayNumber: 1),
                ItineraryItem(name: "Departure Event", category: .transit, dayNumber: 4),
                ItineraryItem(name: "Dinner", category: .food, dayNumber: 2)
            ],
            for: trip,
            in: context
        )

        #expect(trip.itineraryItems.filter(\.isDepartureEvent).map(\.name) == ["Departure Event"])
        #expect(trip.itineraryItems.map(\.name) == ["Dinner", "Departure Event"])
    }

    @MainActor
    @Test("Reviewed plan save validates title and named items", .bug("https://github.com/heathdj/TripPlanner/issues/8"))
    func reviewedPlanSaveValidatesTitleAndNamedItems() throws {
        let storeURL = temporaryStoreURL()
        try removeStore(at: storeURL)
        defer { try? removeStore(at: storeURL) }

        let container = try makeContainer(at: storeURL)
        let context = ModelContext(container)
        let trip = Trip(
            title: "Invalid",
            location: "Test",
            windowStartDate: date(year: 2026, month: 10, day: 1),
            windowEndDate: date(year: 2026, month: 10, day: 3),
            durationDays: 2
        )
        context.insert(trip)

        #expect(throws: ReviewedTripPlanStore.ValidationError.missingTitle) {
            try ReviewedTripPlanStore.saveReviewedPlan(
                title: " ",
                overview: "Overview",
                items: [ItineraryItem(name: "Museum", category: .activity, dayNumber: 1)],
                for: trip,
                in: context
            )
        }

        #expect(throws: ReviewedTripPlanStore.ValidationError.missingItems) {
            try ReviewedTripPlanStore.saveReviewedPlan(
                title: "Valid title",
                overview: "Overview",
                items: [ItineraryItem(name: " ", category: .activity, dayNumber: 1)],
                for: trip,
                in: context
            )
        }
    }

    @Test("Destination suggestions combine title and subtitle cleanly")
    func destinationSuggestionsCombineTitleAndSubtitleCleanly() {
        let city = DestinationSuggestion(title: "Sydney", subtitle: "New South Wales, Australia")
        let country = DestinationSuggestion(title: "Japan", subtitle: "")

        #expect(city.displayText == "Sydney, New South Wales, Australia")
        #expect(country.displayText == "Japan")
    }

    @Test("Activity place suggestions combine title and subtitle cleanly", .bug("https://github.com/heathdj/TripPlanner/issues/45"))
    func activityPlaceSuggestionsCombineTitleAndSubtitleCleanly() {
        let place = ActivityPlaceSuggestion(title: "Sydney Opera House", subtitle: "Bennelong Point")
        let manualFallback = ActivityPlaceSuggestion(title: "Neighborhood walk", subtitle: "")

        #expect(place.displayText == "Sydney Opera House, Bennelong Point")
        #expect(manualFallback.displayText == "Neighborhood walk")
        #expect(place.hasResolvedPlaceDetails == false)
    }

    @MainActor
    @Test("Sample trips include dashboard detail content", .bug("https://github.com/heathdj/TripPlanner/issues/4"))
    func sampleTripsIncludeDashboardDetailContent() {
        let trips = TripStore.sampleTrips

        #expect(trips.count >= 3)
        #expect(trips.allSatisfy { $0.travelerCount > 0 })
        #expect(trips.allSatisfy { $0.plannedItemCount > 0 })
        #expect(trips.allSatisfy { $0.itineraryItems.isEmpty == false })
        #expect(trips.flatMap(\.itineraryItems).contains { $0.hasCoordinate })
        #expect(trips.flatMap(\.itineraryItems).contains { $0.hasCoordinate == false })
    }

    @MainActor
    @Test("App info exposes about and privacy details", .bug("https://github.com/heathdj/TripPlanner/issues/1"))
    func appInfoSummaryIncludesVersionAndBuild() throws {
        let privacyURL = try #require(URL(string: "https://example.com/privacy"))
        let appInfo = AppInfo(
            displayName: "Trip Planner",
            version: "1.0",
            build: "42",
            contactEmail: "support@example.com",
            privacyURL: privacyURL
        )

        #expect(appInfo.versionSummary == "Version 1.0 (42)")
        #expect(appInfo.contactEmail == "support@example.com")
        #expect(appInfo.privacyURL.absoluteString == "https://example.com/privacy")
    }

    @MainActor
    @Test("App icon options expose primary and alternate icons", .bug("https://github.com/heathdj/TripPlanner/issues/36"))
    func appIconOptionsExposeConfiguredChoices() {
        let options = AppIconOption.all

        #expect(options.count == 4)
        #expect(options[0].iconName == nil)
        #expect(options.dropFirst().map(\.iconName) == [
            "AppIcon-CompassSpark",
            "AppIcon-LayeredItinerary",
            "AppIcon-RouteCase"
        ])
        #expect(AppIconOption.option(for: "AppIcon-RouteCase").displayName == "Route Case")
        #expect(AppIconOption.option(for: "Missing").displayName == "Map Pins")
    }

    @MainActor
    @Test("Info plist declares alternate app icons", .bug("https://github.com/heathdj/TripPlanner/issues/36"))
    func infoPlistDeclaresAlternateIcons() throws {
        let icons = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let alternateIcons = try #require(icons["CFBundleAlternateIcons"] as? [String: Any])

        #expect(Set(alternateIcons.keys) == [
            "AppIcon-CompassSpark",
            "AppIcon-LayeredItinerary",
            "AppIcon-RouteCase"
        ])
    }

    @MainActor
    @Test("App icon manager records supported selections", .bug("https://github.com/heathdj/TripPlanner/issues/36"))
    func appIconManagerRecordsSupportedSelection() async throws {
        let manager = FakeAppIconManager(supportsAlternateIcons: true)

        try await manager.setIconName("AppIcon-CompassSpark")

        #expect(manager.currentIconName == "AppIcon-CompassSpark")
        #expect(manager.requestedIconNames == ["AppIcon-CompassSpark"])
    }

    @MainActor
    @Test("App icon manager rejects unsupported devices", .bug("https://github.com/heathdj/TripPlanner/issues/36"))
    func appIconManagerRejectsUnsupportedDevices() async throws {
        let manager = FakeAppIconManager(supportsAlternateIcons: false)

        await #expect(throws: AppIconError.alternateIconsUnsupported) {
            try await manager.setIconName("AppIcon-RouteCase")
        }
        #expect(manager.currentIconName == nil)
        #expect(manager.requestedIconNames.isEmpty)
    }

    @MainActor
    private func trip(
        title: String,
        startDay: Int,
        endDay: Int,
        status: TripStatus,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> Trip {
        Trip(
            title: title,
            location: "Test",
            windowStartDate: date(year: 2026, month: 5, day: startDay),
            windowEndDate: date(year: 2026, month: 5, day: endDay),
            durationDays: 2,
            status: status,
            latitude: latitude,
            longitude: longitude
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .now
    }

    private func localDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    private func makeContainer(at storeURL: URL) throws -> ModelContainer {
        let schema = Schema([
            Trip.self,
            ReviewedTripPlan.self,
            TravelSettings.self
        ])
        let configuration = ModelConfiguration(
            "TripPlannerTests",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func temporaryStoreURL() -> URL {
        URL.temporaryDirectory.appending(path: "TripPlannerTests-\(UUID().uuidString).store")
    }

    private func removeStore(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let relatedURLs = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal")
        ]

        for url in relatedURLs where fileManager.fileExists(atPath: url.path()) {
            try fileManager.removeItem(at: url)
        }
    }
}

@MainActor
private final class FakeAppIconManager: AppIconManaging {
    let supportsAlternateIcons: Bool
    var currentIconName: String?
    var requestedIconNames: [String?] = []

    init(supportsAlternateIcons: Bool) {
        self.supportsAlternateIcons = supportsAlternateIcons
    }

    func setIconName(_ iconName: String?) async throws {
        guard supportsAlternateIcons else {
            throw AppIconError.alternateIconsUnsupported
        }

        requestedIconNames.append(iconName)
        currentIconName = iconName
    }
}
