import Foundation

nonisolated struct TripSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var location: String
    var dateRange: String
    var durationSummary: String
    var startDateSummary: String
    var status: TripStatus
    var closedOutcomeSummary: String?
    var highlight: String
    var plannedItemCount: Int
    var completedItemCount: Int
    var travelerSummary: String
    var progressSummary: String
    var progressFraction: Double

    init(
        id: UUID = UUID(),
        title: String,
        location: String,
        dateRange: String,
        durationSummary: String,
        startDateSummary: String,
        status: TripStatus,
        closedOutcomeSummary: String? = nil,
        highlight: String,
        plannedItemCount: Int,
        completedItemCount: Int = 0,
        travelerSummary: String = "1 traveler",
        progressSummary: String? = nil,
        progressFraction: Double = 0
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.dateRange = dateRange
        self.durationSummary = durationSummary
        self.startDateSummary = startDateSummary
        self.status = status
        self.closedOutcomeSummary = closedOutcomeSummary
        self.highlight = highlight
        self.plannedItemCount = plannedItemCount
        self.completedItemCount = completedItemCount
        self.travelerSummary = travelerSummary
        self.progressSummary = progressSummary ?? "\(completedItemCount) of \(plannedItemCount) planned"
        self.progressFraction = min(max(progressFraction, 0), 1)
    }
}
