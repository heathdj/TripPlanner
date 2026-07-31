import Foundation

enum TripStatus: String, CaseIterable, Identifiable, Sendable {
    case nearby = "Nearby"
    case planning = "Planning"
    case booked = "Booked"
    case complete = "Complete"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .nearby:
            "location.fill"
        case .planning:
            "map"
        case .booked:
            "checkmark.seal.fill"
        case .complete:
            "archivebox.fill"
        }
    }
}
