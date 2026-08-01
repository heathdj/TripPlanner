import SwiftData
import SwiftUI

@main
struct Trip_PlannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Trip.self,
            ReviewedTripPlan.self,
            TravelSettings.self
        ])
    }
}
