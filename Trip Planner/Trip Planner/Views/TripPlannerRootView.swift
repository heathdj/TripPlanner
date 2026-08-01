import SwiftUI

struct TripPlannerRootView: View {
    let appInfo: AppInfo

    var body: some View {
        TabView {
            Tab("Trips", systemImage: "map") {
                DashboardView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView(appInfo: appInfo)
            }
        }
        .tint(.teal)
    }
}
