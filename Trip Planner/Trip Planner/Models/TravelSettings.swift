import Foundation
import SwiftData

@Model
final class TravelSettings {
    var id: UUID
    var defaultDurationDays: Int
    var defaultWindowLengthDays: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        defaultDurationDays: Int = TravelSettings.defaultDurationDays,
        defaultWindowLengthDays: Int = TravelSettings.defaultWindowLengthDays,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.defaultDurationDays = max(1, defaultDurationDays)
        self.defaultWindowLengthDays = max(1, defaultWindowLengthDays)
        self.updatedAt = updatedAt
    }

    func updateDefaultDuration(days: Int) {
        defaultDurationDays = max(1, days)
        updatedAt = .now
    }

    func updateDefaultWindowLength(days: Int) {
        defaultWindowLengthDays = max(1, days)
        updatedAt = .now
    }

    static let defaultDurationDays = 14
    static let defaultWindowLengthDays = 45
}
