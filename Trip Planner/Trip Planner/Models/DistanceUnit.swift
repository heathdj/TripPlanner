import Foundation

/// Stores the user's preferred distance display while keeping persisted radius values in kilometers.
enum DistanceUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case kilometers
    case miles

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kilometers:
            return "Kilometers"
        case .miles:
            return "Miles"
        }
    }

    var symbol: String {
        switch self {
        case .kilometers:
            return "km"
        case .miles:
            return "mi"
        }
    }

    func kilometers(from value: Double) -> Double {
        switch self {
        case .kilometers:
            return value
        case .miles:
            return value * 1.609344
        }
    }

    func value(fromKilometers kilometers: Double) -> Double {
        switch self {
        case .kilometers:
            return kilometers
        case .miles:
            return kilometers / 1.609344
        }
    }

    func formattedDistance(meters: Double) -> String {
        let kilometers = meters / 1_000
        let value = value(fromKilometers: kilometers)
        let roundedValue = value >= 10 ? value.rounded() : (value * 10).rounded() / 10
        return "\(roundedValue.formatted(.number.precision(.fractionLength(roundedValue.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)))) \(symbol)"
    }
}
