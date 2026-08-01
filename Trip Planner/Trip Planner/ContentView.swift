import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    private let appInfoProvider = BundleAppInfoProvider()

    var body: some View {
        TripPlannerRootView(appInfo: appInfoProvider.appInfo)
            .task {
                try? TripSeedService.seedIfNeeded(in: modelContext)
            }
    }
}
