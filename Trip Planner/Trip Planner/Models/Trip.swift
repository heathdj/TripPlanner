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
        durationDays == 1 ? "1 day away" : "\(durationDays) days away"
    }

    var startDateDisplayString: String {
        validStartDateCount == 1 ? "1 possible start date" : "\(validStartDateCount) possible start dates"
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
            startDateSummary: startDateDisplayString,
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
