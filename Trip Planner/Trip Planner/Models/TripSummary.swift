import Foundation

struct TripSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var location: String
    var dateRange: String
    var status: TripStatus
    var highlight: String
    var plannedItemCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        location: String,
        dateRange: String,
        status: TripStatus,
        highlight: String,
        plannedItemCount: Int
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.dateRange = dateRange
        self.status = status
        self.highlight = highlight
        self.plannedItemCount = plannedItemCount
    }
}
