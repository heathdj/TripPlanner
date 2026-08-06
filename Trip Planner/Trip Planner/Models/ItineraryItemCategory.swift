import Foundation

enum ItineraryItemCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case stay
    case food
    case activity
    case transit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stay:
            return "Stay"
        case .food:
            return "Food"
        case .activity:
            return "Activity"
        case .transit:
            return "Transit"
        }
    }

    var systemImage: String {
        switch self {
        case .stay:
            return "bed.double.fill"
        case .food:
            return "fork.knife"
        case .activity:
            return "figure.walk"
        case .transit:
            return "tram.fill"
        }
    }
}
