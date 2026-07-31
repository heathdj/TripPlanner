import Foundation
import Testing
@testable import Trip_Planner

struct TripPlannerFoundationTests {
    @MainActor
    @Test("Sample trips include active release-planning data", .bug("https://github.com/heathdj/TripPlanner/issues/1"))
    func sampleTripsExposeDashboardCounts() {
        let store = TripStore()

        #expect(store.trips.count == 3)
        #expect(store.activeTrips.count == 3)
        #expect(store.plannedItemTotal == 44)
        #expect(store.nextTrip?.title == "Pacific Northwest Loop")
    }

    @MainActor
    @Test("Trip status metadata supports accessible visual labels", .bug("https://github.com/heathdj/TripPlanner/issues/1"), arguments: TripStatus.allCases)
    func tripStatusesHaveSymbols(status: TripStatus) {
        #expect(status.rawValue.isEmpty == false)
        #expect(status.systemImage.isEmpty == false)
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
}
