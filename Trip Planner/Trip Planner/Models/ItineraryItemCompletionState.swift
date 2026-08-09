import Foundation

nonisolated enum ItineraryItemCompletionState: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case planned = "Planned"
    case completed = "Done"
    case skipped = "Skipped"

    var id: String {
        rawValue
    }

    var displayName: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .planned:
            return "circle"
        case .completed:
            return "checkmark.circle.fill"
        case .skipped:
            return "forward.circle.fill"
        }
    }
}
