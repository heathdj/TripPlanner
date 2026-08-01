import Foundation

struct TripSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var location: String
    var dateRange: String
    var durationSummary: String
    var startDateSummary: String
    var status: TripStatus
    var highlight: String
    var plannedItemCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        location: String,
        dateRange: String,
        durationSummary: String,
        startDateSummary: String,
        status: TripStatus,
        highlight: String,
        plannedItemCount: Int
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.dateRange = dateRange
        self.durationSummary = durationSummary
        self.startDateSummary = startDateSummary
        self.status = status
        self.highlight = highlight
        self.plannedItemCount = plannedItemCount
    }
}
