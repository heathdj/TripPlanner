import Foundation

enum TripStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case open = "Open"
    case closed = "Closed"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .open:
            "map"
        case .closed:
            "archivebox.fill"
        }
    }
}
