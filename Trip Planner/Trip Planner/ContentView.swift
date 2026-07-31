import SwiftUI

struct ContentView: View {
    private let store = TripStore()
    private let appInfoProvider = BundleAppInfoProvider()

    var body: some View {
        TripPlannerRootView(
            store: store,
            appInfo: appInfoProvider.appInfo
        )
    }
}
