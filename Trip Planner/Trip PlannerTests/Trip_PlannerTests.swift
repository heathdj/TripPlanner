import Foundation
import CoreLocation
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
    @Test("Trip list facts expose travelers and progress", .bug("https://github.com/heathdj/TripPlanner/issues/4"))
    func tripListFactsExposeTravelersAndProgress() {
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
                ItineraryItem(name: "Arrive", category: .transit, dayNumber: 0),
                ItineraryItem(name: "Explore", category: .activity, dayNumber: 2)
            ]
        )
        let summary = trip.summary()

        #expect(trip.completedItemCount == 5)
        #expect(trip.travelerCount == 1)
        #expect(trip.progressFraction == 1)
        #expect(summary.travelerSummary == "1 traveler")
        #expect(summary.progressSummary == "5 of 5 planned")
        #expect(trip.itineraryItems.map(\.name) == ["Arrive", "Explore"])
        #expect(trip.itineraryItems[0].dayNumber == 1)
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
        #expect(settings.selectedInterestNames == ["Museums", "Local Food", "pottery"])
        #expect(settings.customInterestNames == ["pottery"])
        #expect(settings.visibleSelectedInterests == ["Museums", "Local Food", "pottery"])

        settings.toggleInterest("Museums")
        settings.removeCustomInterest("POTTERY")

        #expect(settings.isInterestSelected("Museums") == false)
        #expect(settings.selectedInterestNames == ["Local Food"])
        #expect(settings.customInterestNames.isEmpty)
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
        #expect(draft.items.map(\.dayNumber) == [1, 1, 2, 3])
        #expect(draft.items.map(\.category) == [.transit, .stay, .activity, .food])
        #expect(draft.items[1].name == "Trip idea")
    }

    @MainActor
    @Test("Nearby grouping promotes only open trips inside the radius", .bug("https://github.com/heathdj/TripPlanner/issues/3"))
    func nearbyGroupingPromotesOpenTripsInsideRadius() {
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
        let nearbyClosed = trip(
            title: "Closed nearby",
            startDay: 5,
            endDay: 6,
            status: .closed,
            latitude: 41.8818,
            longitude: -87.6231
        )

        let groups = TripStore.groupedTrips(
            [farOpen, nearbyClosed, nearbyOpen],
            userLocation: userLocation,
            nearYouDistanceKilometers: 100
        )

        #expect(groups.nearbyTrips.map(\.trip.title) == ["Nearby"])
        #expect(groups.openTrips.map(\.title) == ["Far"])
        #expect(groups.closedTrips.map(\.title) == ["Closed nearby"])
    }

    @MainActor
    @Test("Grouping without location keeps open and closed trips visible", .bug("https://github.com/heathdj/TripPlanner/issues/3"))
    func groupingWithoutLocationKeepsOpenAndClosedTripsVisible() {
        let open = trip(
            title: "Open",
            startDay: 1,
            endDay: 2,
            status: .open,
            latitude: 41.8818,
            longitude: -87.6231
        )
        let closed = trip(title: "Closed", startDay: 3, endDay: 4, status: .closed)

        let groups = TripStore.groupedTrips(
            [closed, open],
            userLocation: nil,
            nearYouDistanceKilometers: 100
        )

        #expect(groups.nearbyTrips.isEmpty)
        #expect(groups.openTrips.map(\.title) == ["Open"])
        #expect(groups.closedTrips.map(\.title) == ["Closed"])
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
            status: .open,
            highlight: "Local food and museum mornings.",
            plannedItemCount: 6,
            completedItemCount: 2,
            travelerCount: 3,
            itineraryItems: [
                ItineraryItem(name: "Museum morning", category: .activity, dayNumber: 1),
                ItineraryItem(name: "Dinner reservation", category: .food, dayNumber: 2)
            ]
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
        #expect(persistedTrip.completedItemCount == 2)
        #expect(persistedTrip.travelerDisplayString == "3 travelers")
        #expect(persistedTrip.itineraryItems.map(\.name) == ["Museum morning", "Dinner reservation"])
        #expect(persistedTrip.itineraryItems.map(\.category) == [.activity, .food])
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

        #expect(persistedSetting.selectedInterestNames == ["Hikes", "Gardens", "Jazz Clubs"])
        #expect(persistedSetting.customInterestNames == ["Gardens", "Jazz Clubs"])
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
