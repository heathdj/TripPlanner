import Foundation

enum TripStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case open = "Open"
    case planned = "Planned"
    case active = "Active"
    case closed = "Closed"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .open:
            "map"
        case .planned:
            "calendar.badge.checkmark"
        case .active:
            "location.fill"
        case .closed:
            "archivebox.fill"
        }
    }
}

enum ClosedTripOutcome: String, Codable, CaseIterable, Identifiable, Sendable {
    case completed = "Completed"
    case cancelled = "Cancelled"

    var id: String { rawValue }
}
