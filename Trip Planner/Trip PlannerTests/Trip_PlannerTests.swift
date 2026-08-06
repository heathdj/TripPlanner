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
        #expect(trip.durationDisplayString == "4 days away")
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
            plannedItemCount: 6
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
        #expect(persistedSetting.defaultDurationDays == 14)
        #expect(persistedSetting.defaultWindowLengthDays == 45)
        #expect(persistedSetting.distanceUnit == .kilometers)
        #expect(persistedSetting.nearYouDistanceKilometers == 100)
        #expect(persistedPlan.tripID == persistedTrip.id)
        #expect(persistedPlan.title == "Reviewed Santa Fe plan")
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
