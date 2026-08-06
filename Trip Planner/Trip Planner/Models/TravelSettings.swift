import Foundation
import SwiftData

@Model
final class TravelSettings {
    var id: UUID
    var defaultDurationDays: Int
    var defaultWindowLengthDays: Int
    var distanceUnitRawValue: String = DistanceUnit.kilometers.rawValue
    var nearYouDistanceKilometers: Double = TravelSettings.defaultNearYouDistanceKilometers
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        defaultDurationDays: Int = TravelSettings.defaultDurationDays,
        defaultWindowLengthDays: Int = TravelSettings.defaultWindowLengthDays,
        distanceUnit: DistanceUnit = .kilometers,
        nearYouDistanceKilometers: Double = TravelSettings.defaultNearYouDistanceKilometers,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.defaultDurationDays = max(1, defaultDurationDays)
        self.defaultWindowLengthDays = max(1, defaultWindowLengthDays)
        self.distanceUnitRawValue = distanceUnit.rawValue
        self.nearYouDistanceKilometers = max(1, nearYouDistanceKilometers)
        self.updatedAt = updatedAt
    }

    var distanceUnit: DistanceUnit {
        get {
            DistanceUnit(rawValue: distanceUnitRawValue) ?? .kilometers
        }
        set {
            distanceUnitRawValue = newValue.rawValue
            updatedAt = .now
        }
    }

    var nearYouDistanceValue: Double {
        distanceUnit.value(fromKilometers: nearYouDistanceKilometers)
    }

    var nearYouDistanceDisplayString: String {
        "\(nearYouDistanceValue.formatted(.number.precision(.fractionLength(0)))) \(distanceUnit.symbol)"
    }

    func updateDefaultDuration(days: Int) {
        defaultDurationDays = max(1, days)
        updatedAt = .now
    }

    func updateDefaultWindowLength(days: Int) {
        defaultWindowLengthDays = max(1, days)
        updatedAt = .now
    }

    func updateDistanceUnit(_ unit: DistanceUnit) {
        distanceUnit = unit
    }

    func updateNearYouDistance(value: Double, unit: DistanceUnit) {
        nearYouDistanceKilometers = max(1, unit.kilometers(from: value))
        updatedAt = .now
    }

    static let defaultDurationDays = 14
    static let defaultWindowLengthDays = 45
    static let defaultNearYouDistanceKilometers = 100.0
}
