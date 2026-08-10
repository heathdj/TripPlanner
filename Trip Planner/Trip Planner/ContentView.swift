import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    private let appInfoProvider = BundleAppInfoProvider()

    var body: some View {
        TripPlannerRootView(appInfo: appInfoProvider.appInfo)
            .task {
                do {
                    if try TripSeedService.seedUITestScenarioIfNeeded(in: modelContext) == false {
                        try TripSeedService.seedIfNeeded(in: modelContext)
                    }
                } catch {
                    assertionFailure("Failed to seed Trip Planner data: \(error.localizedDescription)")
                }
            }
    }
}
