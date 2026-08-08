import Foundation

enum TravelPreferencesStorage {
    enum Key {
        static let defaultDurationDays = "travelPreferences.defaultDurationDays"
        static let defaultWindowLengthDays = "travelPreferences.defaultWindowLengthDays"
        static let distanceUnit = "travelPreferences.distanceUnit"
        static let nearYouDistanceKilometers = "travelPreferences.nearYouDistanceKilometers"
        static let selectedInterestNames = "travelPreferences.selectedInterestNames"
        static let customInterestNames = "travelPreferences.customInterestNames"
    }

    static let defaultSelectedInterestsData = "[]"
    static let defaultCustomInterestsData = "[]"

    static func decodeInterests(from data: String) -> [String] {
        guard let jsonData = data.data(using: .utf8),
              let interests = try? JSONDecoder().decode([String].self, from: jsonData)
        else {
            return []
        }

        return normalizedInterests(from: interests)
    }

    static func encodeInterests(_ interests: [String]) -> String {
        let normalized = normalizedInterests(from: interests)
        guard let data = try? JSONEncoder().encode(normalized),
              let string = String(data: data, encoding: .utf8)
        else {
            return defaultSelectedInterestsData
        }

        return string
    }

    static func visibleSelectedInterests(selected: [String], custom: [String]) -> [String] {
        let builtIns = ActivityInterestCatalog.builtInInterests.filter { isInterestSelected($0, selected: selected) }
        let selectedCustom = custom.filter { isInterestSelected($0, selected: selected) }
        return builtIns + selectedCustom
    }

    static func isInterestSelected(_ interest: String, selected: [String]) -> Bool {
        selected.contains { $0.localizedCaseInsensitiveCompare(interest) == .orderedSame }
    }

    static func toggledInterest(_ interest: String, selected: [String]) -> [String] {
        let normalized = interest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return normalizedInterests(from: selected) }

        var interests = normalizedInterests(from: selected)
        if let index = interests.firstIndex(where: { $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) {
            interests.remove(at: index)
        } else {
            interests.append(normalized)
        }

        return interests
    }

    static func addingCustomInterest(
        _ interest: String,
        selected: [String],
        custom: [String]
    ) -> (selected: [String], custom: [String]) {
        let normalized = interest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            return (normalizedInterests(from: selected), normalizedInterests(from: custom))
        }

        var customInterests = normalizedInterests(from: custom)
        if customInterests.contains(where: { $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) == false,
           ActivityInterestCatalog.builtInInterests.contains(where: { $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) == false {
            customInterests.append(normalized)
        }

        var selectedInterests = normalizedInterests(from: selected)
        if isInterestSelected(normalized, selected: selectedInterests) == false {
            selectedInterests.append(normalized)
        }

        return (selectedInterests, customInterests)
    }

    static func removingCustomInterest(
        _ interest: String,
        selected: [String],
        custom: [String]
    ) -> (selected: [String], custom: [String]) {
        let selectedInterests = normalizedInterests(from: selected)
            .filter { $0.localizedCaseInsensitiveCompare(interest) != .orderedSame }
        let customInterests = normalizedInterests(from: custom)
            .filter { $0.localizedCaseInsensitiveCompare(interest) != .orderedSame }

        return (selectedInterests, customInterests)
    }

    static func normalizedInterests(from interests: [String]) -> [String] {
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
}
