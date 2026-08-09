import CoreLocation
import Foundation

nonisolated struct ActivationPromptRecord: Codable, Equatable, Sendable {
    var lastPromptedAt: Date?
    var lastPromptReasons: [ActivationPromptReason]
    var dismissedAt: Date?
    var cooldownUntil: Date?
    var isSuppressed: Bool

    init(
        lastPromptedAt: Date? = nil,
        lastPromptReasons: [ActivationPromptReason] = [],
        dismissedAt: Date? = nil,
        cooldownUntil: Date? = nil,
        isSuppressed: Bool = false
    ) {
        self.lastPromptedAt = lastPromptedAt
        self.lastPromptReasons = lastPromptReasons
        self.dismissedAt = dismissedAt
        self.cooldownUntil = cooldownUntil
        self.isSuppressed = isSuppressed
    }
}

nonisolated struct ActivationPromptState: Codable, Equatable, Sendable {
    var recordsByTripID: [String: ActivationPromptRecord] = [:]
}

nonisolated enum ActivationPromptReason: String, Codable, Equatable, Sendable {
    case date
    case proximity

    var displayName: String {
        switch self {
        case .date:
            return "scheduled date"
        case .proximity:
            return "nearby destination"
        }
    }
}

struct ActivationPromptCandidate: Identifiable {
    let trip: Trip
    let reasons: [ActivationPromptReason]
    let distanceMeters: CLLocationDistance?
    let proposedStartDate: Date

    var id: UUID {
        trip.id
    }

    var title: String {
        "Make \(trip.title) Active?"
    }

    var message: String {
        let reasonSummary: String
        if reasons.contains(.date) && reasons.contains(.proximity) {
            reasonSummary = "It is scheduled around now and you are near the destination."
        } else if reasons.contains(.date) {
            reasonSummary = "It is scheduled to start soon or is currently within its trip dates."
        } else {
            reasonSummary = "You are near the destination."
        }

        if trip.exactStartDate == nil {
            return "\(reasonSummary) Making it active will set the exact start date to \(proposedStartDate.formatted(date: .abbreviated, time: .omitted))."
        }

        return "\(reasonSummary) Making it active moves it to Active Trips."
    }
}

enum ActivationPromptEligibilityService {
    static let defaultLeadTimeDays = 2
    static let defaultCooldownHours = 24

    static func candidate(
        from trips: [Trip],
        now: Date = .now,
        userLocation: CLLocation?,
        nearYouDistanceKilometers: Double,
        leadTimeDays: Int,
        datePromptsEnabled: Bool,
        proximityPromptsEnabled: Bool,
        state: ActivationPromptState
    ) -> ActivationPromptCandidate? {
        TripStore.sortedTrips(trips)
            .lazy
            .compactMap { trip in
                candidate(
                    for: trip,
                    now: now,
                    userLocation: userLocation,
                    nearYouDistanceKilometers: nearYouDistanceKilometers,
                    leadTimeDays: leadTimeDays,
                    datePromptsEnabled: datePromptsEnabled,
                    proximityPromptsEnabled: proximityPromptsEnabled,
                    state: state
                )
            }
            .first
    }

    static func candidate(
        for trip: Trip,
        now: Date = .now,
        userLocation: CLLocation?,
        nearYouDistanceKilometers: Double,
        leadTimeDays: Int,
        datePromptsEnabled: Bool,
        proximityPromptsEnabled: Bool,
        state: ActivationPromptState
    ) -> ActivationPromptCandidate? {
        guard trip.status == .open || trip.status == .planned,
              isSuppressed(tripID: trip.id, in: state) == false,
              isCoolingDown(tripID: trip.id, now: now, in: state) == false
        else {
            return nil
        }

        var reasons = [ActivationPromptReason]()
        if isDateEligible(
            trip,
            now: now,
            leadTimeDays: leadTimeDays,
            isEnabled: datePromptsEnabled,
            timeZone: destinationTimeZone(for: trip)
        ) {
            reasons.append(.date)
        }

        let distanceMeters = proximityDistance(
            for: trip,
            userLocation: userLocation,
            nearYouDistanceKilometers: nearYouDistanceKilometers,
            isEnabled: proximityPromptsEnabled
        )
        if distanceMeters != nil {
            reasons.append(.proximity)
        }

        guard reasons.isEmpty == false else { return nil }
        return ActivationPromptCandidate(
            trip: trip,
            reasons: reasons,
            distanceMeters: distanceMeters,
            proposedStartDate: now
        )
    }

    static func isDateEligible(
        _ trip: Trip,
        now: Date,
        leadTimeDays: Int,
        isEnabled: Bool,
        timeZone: TimeZone
    ) -> Bool {
        guard isEnabled,
              let exactStartDate = trip.exactStartDate,
              let exactEndDate = trip.exactEndDate
        else {
            return false
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)
        let startDay = calendar.startOfDay(for: exactStartDate)
        let endDay = calendar.startOfDay(for: exactEndDate)
        let leadStartDay = calendar.date(
            byAdding: .day,
            value: -max(0, leadTimeDays),
            to: startDay
        ) ?? startDay

        return today >= leadStartDay && today <= endDay
    }

    static func proximityDistance(
        for trip: Trip,
        userLocation: CLLocation?,
        nearYouDistanceKilometers: Double,
        isEnabled: Bool
    ) -> CLLocationDistance? {
        guard isEnabled,
              let userLocation,
              let latitude = trip.latitude,
              let longitude = trip.longitude
        else {
            return nil
        }

        let distance = userLocation.distance(from: CLLocation(latitude: latitude, longitude: longitude))
        return distance <= max(1, nearYouDistanceKilometers) * 1_000 ? distance : nil
    }

    static func destinationTimeZone(for trip: Trip) -> TimeZone {
        trip.itineraryItems
            .lazy
            .compactMap(\.placeTimeZone)
            .first ?? .current
    }

    static func recordPromptShown(
        for tripID: UUID,
        reasons: [ActivationPromptReason],
        at date: Date,
        in state: ActivationPromptState
    ) -> ActivationPromptState {
        var updatedState = state
        var record = updatedState.record(for: tripID)
        record.lastPromptedAt = date
        record.lastPromptReasons = reasons
        updatedState.setRecord(record, for: tripID)
        return updatedState
    }

    static func dismiss(
        tripID: UUID,
        reasons: [ActivationPromptReason],
        at date: Date,
        cooldownHours: Int = defaultCooldownHours,
        in state: ActivationPromptState
    ) -> ActivationPromptState {
        var updatedState = state
        var record = updatedState.record(for: tripID)
        record.dismissedAt = date
        record.lastPromptReasons = reasons
        record.cooldownUntil = Calendar.current.date(byAdding: .hour, value: max(1, cooldownHours), to: date)
        updatedState.setRecord(record, for: tripID)
        return updatedState
    }

    static func suppress(
        tripID: UUID,
        reasons: [ActivationPromptReason],
        at date: Date,
        in state: ActivationPromptState
    ) -> ActivationPromptState {
        var updatedState = state
        var record = updatedState.record(for: tripID)
        record.dismissedAt = date
        record.lastPromptReasons = reasons
        record.cooldownUntil = nil
        record.isSuppressed = true
        updatedState.setRecord(record, for: tripID)
        return updatedState
    }

    static func resetSuppression(tripID: UUID, in state: ActivationPromptState) -> ActivationPromptState {
        var updatedState = state
        var record = updatedState.record(for: tripID)
        record.isSuppressed = false
        record.cooldownUntil = nil
        updatedState.setRecord(record, for: tripID)
        return updatedState
    }

    static func resetAllSuppressions(in state: ActivationPromptState) -> ActivationPromptState {
        var updatedState = state
        for tripID in updatedState.recordsByTripID.keys {
            guard var record = updatedState.recordsByTripID[tripID] else { continue }
            record.isSuppressed = false
            record.cooldownUntil = nil
            updatedState.recordsByTripID[tripID] = record
        }
        return updatedState
    }

    static func isSuppressed(tripID: UUID, in state: ActivationPromptState) -> Bool {
        state.record(for: tripID).isSuppressed
    }

    static func isCoolingDown(tripID: UUID, now: Date, in state: ActivationPromptState) -> Bool {
        guard let cooldownUntil = state.record(for: tripID).cooldownUntil else { return false }
        return cooldownUntil > now
    }
}

extension ActivationPromptState {
    func record(for tripID: UUID) -> ActivationPromptRecord {
        recordsByTripID[tripID.uuidString] ?? ActivationPromptRecord()
    }

    mutating func setRecord(_ record: ActivationPromptRecord, for tripID: UUID) {
        recordsByTripID[tripID.uuidString] = record
    }
}
