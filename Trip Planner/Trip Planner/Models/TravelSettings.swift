import Foundation
import SwiftData

@Model
final class TravelSettings {
    var id: UUID
    var defaultDurationDays: Int
    var defaultWindowLengthDays: Int
    var distanceUnitRawValue: String = DistanceUnit.kilometers.rawValue
    var nearYouDistanceKilometers: Double = TravelSettings.defaultNearYouDistanceKilometers
    var selectedInterestNames: [String]
    var customInterestNames: [String]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        defaultDurationDays: Int = TravelSettings.defaultDurationDays,
        defaultWindowLengthDays: Int = TravelSettings.defaultWindowLengthDays,
        distanceUnit: DistanceUnit = .kilometers,
        nearYouDistanceKilometers: Double = TravelSettings.defaultNearYouDistanceKilometers,
        selectedInterestNames: [String] = [],
        customInterestNames: [String] = [],
        updatedAt: Date = .now
    ) {
        self.id = id
        self.defaultDurationDays = max(1, defaultDurationDays)
        self.defaultWindowLengthDays = max(1, defaultWindowLengthDays)
        self.distanceUnitRawValue = distanceUnit.rawValue
        self.nearYouDistanceKilometers = max(1, nearYouDistanceKilometers)
        self.selectedInterestNames = Self.normalizedInterests(from: selectedInterestNames)
        self.customInterestNames = Self.normalizedInterests(from: customInterestNames)
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

    var visibleSelectedInterests: [String] {
        let builtIns = ActivityInterestCatalog.builtInInterests.filter { isInterestSelected($0) }
        let custom = customInterestNames.filter { isInterestSelected($0) }
        return builtIns + custom
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

    func isInterestSelected(_ interest: String) -> Bool {
        selectedInterestNames.contains { $0.localizedCaseInsensitiveCompare(interest) == .orderedSame }
    }

    func toggleInterest(_ interest: String) {
        let normalized = interest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return }

        if let index = selectedInterestNames.firstIndex(where: { $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) {
            selectedInterestNames.remove(at: index)
        } else {
            selectedInterestNames.append(normalized)
        }

        updatedAt = .now
    }

    func addCustomInterest(_ interest: String) {
        let normalized = interest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return }

        if customInterestNames.contains(where: { $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) == false,
           ActivityInterestCatalog.builtInInterests.contains(where: { $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) == false {
            customInterestNames.append(normalized)
        }

        if isInterestSelected(normalized) == false {
            selectedInterestNames.append(normalized)
        }

        updatedAt = .now
    }

    func removeCustomInterest(_ interest: String) {
        customInterestNames.removeAll { $0.localizedCaseInsensitiveCompare(interest) == .orderedSame }
        selectedInterestNames.removeAll { $0.localizedCaseInsensitiveCompare(interest) == .orderedSame }
        updatedAt = .now
    }

    private static func normalizedInterests(from interests: [String]) -> [String] {
        interests.reduce(into: [String]()) { result, interest in
            let normalized = interest.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.isEmpty == false,
                  result.contains(where: { $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) == false
            else {
                return
            }

            result.append(normalized)
        }
    }

    static let defaultDurationDays = 14
    static let defaultWindowLengthDays = 45
    static let defaultNearYouDistanceKilometers = 100.0
}
