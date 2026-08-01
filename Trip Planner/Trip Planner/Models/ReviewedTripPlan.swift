import Foundation
import SwiftData

@Model
final class ReviewedTripPlan {
    var id: UUID
    var tripID: UUID
    var title: String
    var notes: String
    var reviewedAt: Date

    init(
        id: UUID = UUID(),
        tripID: UUID,
        title: String,
        notes: String,
        reviewedAt: Date = .now
    ) {
        self.id = id
        self.tripID = tripID
        self.title = title
        self.notes = notes
        self.reviewedAt = reviewedAt
    }
}
