import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID
    var title: String
    var location: String
    var windowStartDate: Date
    var windowEndDate: Date
    var durationDays: Int
    var status: TripStatus
    var highlight: String
    var plannedItemCount: Int
    var completedItemCount: Int
    var travelerCount: Int
    var itineraryItems: [ItineraryItem]
    var latitude: Double?
    var longitude: Double?
    var exactStartDate: Date?
    var activatedAt: Date?
    var closedAt: Date?
    var closedOutcome: ClosedTripOutcome?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        location: String,
        windowStartDate: Date,
        windowEndDate: Date,
        durationDays: Int,
        status: TripStatus = .open,
        highlight: String = "",
        plannedItemCount: Int = 0,
        completedItemCount: Int = 0,
        travelerCount: Int = 1,
        itineraryItems: [ItineraryItem] = [],
        latitude: Double? = nil,
        longitude: Double? = nil,
        exactStartDate: Date? = nil,
        activatedAt: Date? = nil,
        closedAt: Date? = nil,
        closedOutcome: ClosedTripOutcome? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.windowStartDate = calendar.startOfDay(for: windowStartDate)
        self.windowEndDate = max(calendar.startOfDay(for: windowStartDate), calendar.startOfDay(for: windowEndDate))
        self.durationDays = max(1, durationDays)
        self.status = status
        self.highlight = highlight
        self.plannedItemCount = max(0, plannedItemCount)
        self.completedItemCount = min(max(0, completedItemCount), max(0, plannedItemCount))
        self.travelerCount = max(1, travelerCount)
        self.itineraryItems = itineraryItems
        self.latitude = latitude
        self.longitude = longitude
        self.exactStartDate = exactStartDate.map { calendar.startOfDay(for: $0) }
        self.activatedAt = activatedAt
        self.closedAt = closedAt
        self.closedOutcome = closedOutcome
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var windowLengthDays: Int {
        Self.dayCount(from: windowStartDate, through: windowEndDate)
    }

    var validStartDateCount: Int {
        max(0, windowLengthDays - durationDays + 1)
    }

    var windowDisplayString: String {
        "\(windowStartDate.formatted(date: .abbreviated, time: .omitted))-\(windowEndDate.formatted(date: .abbreviated, time: .omitted))"
    }

    var durationDisplayString: String {
        durationDays == 1 ? "1 day" : "\(durationDays) days"
    }

    var startDateDisplayString: String {
        validStartDateCount == 1 ? "1 possible start date" : "\(validStartDateCount) possible start dates"
    }

    var exactEndDate: Date? {
        guard let exactStartDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: durationDays - 1, to: exactStartDate)
    }

    var exactDateDisplayString: String {
        guard let exactStartDate,
              let exactEndDate
        else {
            return "Flexible"
        }

        return "\(exactStartDate.formatted(date: .abbreviated, time: .omitted))-\(exactEndDate.formatted(date: .abbreviated, time: .omitted))"
    }

    var effectiveClosedOutcome: ClosedTripOutcome? {
        guard status == .closed else { return nil }
        return closedOutcome ?? .completed
    }

    var travelerDisplayString: String {
        travelerCount == 1 ? "1 traveler" : "\(travelerCount) travelers"
    }

    var progressDisplayString: String {
        "\(completedItemCount) of \(plannedItemCount) planned"
    }

    var progressFraction: Double {
        guard plannedItemCount > 0 else { return 0 }
        return Double(completedItemCount) / Double(plannedItemCount)
    }

    func updateWindow(start: Date, end: Date, calendar: Calendar = .current) {
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: end)
        windowStartDate = normalizedStart
        windowEndDate = max(normalizedStart, normalizedEnd)
        updatedAt = .now
    }

    func updateDuration(days: Int) {
        durationDays = max(1, days)
        if let exactStartDate,
           TripLifecycleService.canSchedule(self, exactStartDate: exactStartDate) == false {
            self.exactStartDate = nil
            status = .open
        }
        updatedAt = .now
    }

    func updateProgress(completedItems: Int, plannedItems: Int? = nil) {
        if let plannedItems {
            plannedItemCount = max(0, plannedItems)
        }

        completedItemCount = min(max(0, completedItems), plannedItemCount)
        updatedAt = .now
    }

    func updateLocation(latitude: Double?, longitude: Double?) {
        self.latitude = latitude
        self.longitude = longitude
        updatedAt = .now
    }

    func summary() -> TripSummary {
        TripSummary(
            id: id,
            title: title,
            location: location,
            dateRange: windowDisplayString,
            durationSummary: durationDisplayString,
            startDateSummary: exactStartDate == nil ? startDateDisplayString : exactDateDisplayString,
            status: status,
            highlight: highlight,
            plannedItemCount: plannedItemCount,
            completedItemCount: completedItemCount,
            travelerSummary: travelerDisplayString,
            progressSummary: progressDisplayString,
            progressFraction: progressFraction
        )
    }

    static func dayCount(from startDate: Date, through endDate: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, days + 1)
    }
}

enum TripLifecycleService {
    enum ValidationError: LocalizedError, Equatable {
        case startDateOutsideWindow
        case tripDoesNotFitWindow
        case cannotClearExactDate
        case cannotActivate
        case cannotClose

        var errorDescription: String? {
            switch self {
            case .startDateOutsideWindow:
                return "Choose a start date inside the flexible travel window."
            case .tripDoesNotFitWindow:
                return "The trip duration must fit before the flexible travel window ends."
            case .cannotClearExactDate:
                return "Only planned trips can move back to open by clearing the exact start date."
            case .cannotActivate:
                return "Only open or planned trips can be started."
            case .cannotClose:
                return "Only open, planned, or active trips can be closed."
            }
        }
    }

    static func canSchedule(_ trip: Trip, exactStartDate: Date, calendar: Calendar = .current) -> Bool {
        (try? validatedEndDate(for: trip, exactStartDate: exactStartDate, calendar: calendar)) != nil
    }

    static func previewExactEndDate(for trip: Trip, exactStartDate: Date, calendar: Calendar = .current) throws -> Date {
        try validatedEndDate(for: trip, exactStartDate: exactStartDate, calendar: calendar)
    }

    @discardableResult
    static func setExactStartDate(_ exactStartDate: Date, for trip: Trip, calendar: Calendar = .current) throws -> Date {
        let exactEndDate = try validatedEndDate(for: trip, exactStartDate: exactStartDate, calendar: calendar)
        trip.exactStartDate = calendar.startOfDay(for: exactStartDate)
        trip.status = .planned
        trip.activatedAt = nil
        trip.closedAt = nil
        trip.closedOutcome = nil
        trip.updatedAt = .now
        return exactEndDate
    }

    static func clearExactStartDate(for trip: Trip) throws {
        guard trip.status == .planned else {
            throw ValidationError.cannotClearExactDate
        }

        trip.exactStartDate = nil
        trip.status = .open
        trip.updatedAt = .now
    }

    static func activate(_ trip: Trip, at date: Date = .now) throws {
        guard trip.status == .open || trip.status == .planned else {
            throw ValidationError.cannotActivate
        }

        trip.status = .active
        trip.activatedAt = date
        trip.closedAt = nil
        trip.closedOutcome = nil
        trip.updatedAt = .now
    }

    static func close(_ trip: Trip, outcome: ClosedTripOutcome, at date: Date = .now) throws {
        guard trip.status == .open || trip.status == .planned || trip.status == .active else {
            throw ValidationError.cannotClose
        }

        trip.status = .closed
        trip.closedAt = date
        trip.closedOutcome = outcome
        trip.updatedAt = .now
    }

    static func normalizeMigratedLifecycle(for trip: Trip) {
        switch trip.status {
        case .open:
            if trip.exactStartDate != nil {
                trip.status = .planned
            }
        case .planned:
            if trip.exactStartDate == nil {
                trip.status = .open
            }
        case .active:
            break
        case .closed:
            if trip.closedOutcome == nil {
                trip.closedOutcome = .completed
            }
        }
    }

    private static func validatedEndDate(for trip: Trip, exactStartDate: Date, calendar: Calendar) throws -> Date {
        let normalizedStart = calendar.startOfDay(for: exactStartDate)
        let windowStart = calendar.startOfDay(for: trip.windowStartDate)
        let windowEnd = calendar.startOfDay(for: trip.windowEndDate)

        guard normalizedStart >= windowStart && normalizedStart <= windowEnd else {
            throw ValidationError.startDateOutsideWindow
        }

        let exactEndDate = calendar.date(byAdding: .day, value: max(1, trip.durationDays) - 1, to: normalizedStart) ?? normalizedStart
        guard exactEndDate <= windowEnd else {
            throw ValidationError.tripDoesNotFitWindow
        }

        return exactEndDate
    }
}
