import SwiftUI

struct TripPlannerRootView: View {
    let store: TripStore
    let appInfo: AppInfo

    var body: some View {
        TabView {
            Tab("Trips", systemImage: "map") {
                DashboardView(store: store)
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView(appInfo: appInfo)
            }
        }
        .tint(.teal)
    }
}
