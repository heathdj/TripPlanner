import Foundation
import FoundationModels

struct TripPlanGenerationInput: Equatable, Sendable {
    let destination: String
    let travelWindow: String
    let durationDays: Int
    let travelerCount: Int
    let theme: String
    let selectedInterests: [String]

    init(
        destination: String,
        travelWindow: String,
        durationDays: Int,
        travelerCount: Int,
        theme: String,
        selectedInterests: [String]
    ) {
        self.destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        self.travelWindow = travelWindow.trimmingCharacters(in: .whitespacesAndNewlines)
        self.durationDays = max(1, durationDays)
        self.travelerCount = max(1, travelerCount)
        self.theme = theme.trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedInterests = selectedInterests
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    init(trip: Trip, selectedInterests: [String]) {
        self.init(
            destination: trip.location,
            travelWindow: trip.windowDisplayString,
            durationDays: trip.durationDays,
            travelerCount: trip.travelerCount,
            theme: trip.highlight,
            selectedInterests: selectedInterests
        )
    }
}

struct TripPlanDraft: Equatable, Sendable {
    var title: String
    var overview: String
    var items: [ItineraryItem]
}

struct TripPlanDraftItemInput: Equatable, Sendable {
    let name: String
    let notes: String
    let category: ItineraryItemCategory
    let dayNumber: Int
}

enum GeneratedItineraryPlaceReviewPolicy {
    static let unresolvedPlaceReviewNote = "Needs exact place review."

    static func itemForReview(_ item: ItineraryItem, durationDays: Int) -> ItineraryItem {
        guard item.hasCoordinate == false,
              item.mapItemIdentifier == nil,
              isBoundaryItem(item, durationDays: durationDays) == false
        else {
            return item
        }

        var reviewedItem = item
        let existingNote = reviewedItem.notesOrAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if existingNote.isEmpty {
            reviewedItem.notesOrAddress = unresolvedPlaceReviewNote
        } else if existingNote.localizedCaseInsensitiveContains(unresolvedPlaceReviewNote) == false {
            reviewedItem.notesOrAddress = "\(existingNote) \(unresolvedPlaceReviewNote)"
        }

        return reviewedItem
    }

    private static func isBoundaryItem(_ item: ItineraryItem, durationDays: Int) -> Bool {
        guard item.category == .transit else { return false }

        let normalized = normalizedText(item.name)
        if item.dayNumber == 1,
           ["arrival", "arrival day", "arrive", "arrive and check in", "check in"].contains(normalized) {
            return true
        }

        if item.dayNumber == max(1, durationDays),
           ["departure", "departure day", "departure event", "depart", "fly home"].contains(normalized) {
            return true
        }

        return false
    }

    private static func normalizedText(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }
}

nonisolated enum TripPlanGenerationStatus: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unavailable

    nonisolated var isAvailable: Bool {
        self == .available
    }

    nonisolated var title: String {
        switch self {
        case .available:
            return "On-device planning ready"
        case .deviceNotEligible:
            return "Apple Intelligence is not supported on this device"
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence"
        case .modelNotReady:
            return "Apple Intelligence is getting ready"
        case .unavailable:
            return "Trip generation is unavailable"
        }
    }

    nonisolated var message: String {
        switch self {
        case .available:
            return "Generate a private draft on this device. Nothing is saved automatically."
        case .deviceNotEligible:
            return "Use a device that supports Apple Intelligence to generate trip drafts on device."
        case .appleIntelligenceNotEnabled:
            return "Enable Apple Intelligence in Settings, then return to Trip Planner to generate a draft."
        case .modelNotReady:
            return "Keep the device connected and try again after Apple Intelligence finishes downloading its model assets."
        case .unavailable:
            return "Try again later, or review the trip details and interests manually for now."
        }
    }
}

enum TripPlanGenerationError: LocalizedError, Sendable {
    case unavailable(TripPlanGenerationStatus)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let status):
            return status.title
        case .generationFailed(let message):
            return message
        }
    }
}

protocol TripPlanGenerating: Sendable {
    var status: TripPlanGenerationStatus { get }

    func generateDraft(for input: TripPlanGenerationInput) async throws -> TripPlanDraft
}

struct FoundationModelsTripPlanGenerator: TripPlanGenerating {
    private let model = SystemLanguageModel.default

    var status: TripPlanGenerationStatus {
        switch model.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .unavailable
        }
    }

    func generateDraft(for input: TripPlanGenerationInput) async throws -> TripPlanDraft {
        guard status.isAvailable else {
            throw TripPlanGenerationError.unavailable(status)
        }

        let session = LanguageModelSession(instructions: Self.instructions)

        do {
            let response = try await session.respond(
                to: Self.prompt(for: input),
                generating: FoundationModelTripPlan.self
            )

            return TripPlanGenerationSanitizer.draft(
                from: response.content,
                durationDays: input.durationDays
            )
        } catch LanguageModelSession.GenerationError.assetsUnavailable {
            throw TripPlanGenerationError.unavailable(.modelNotReady)
        } catch LanguageModelSession.GenerationError.unsupportedLanguageOrLocale {
            throw TripPlanGenerationError.generationFailed("Apple Intelligence does not support one of the languages in this trip yet. Try editing the trip details and generating again.")
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            throw TripPlanGenerationError.generationFailed("Apple Intelligence could not create a safe draft from these trip details. Review the destination, theme, and interests, then try again.")
        } catch LanguageModelSession.GenerationError.refusal {
            throw TripPlanGenerationError.generationFailed("Apple Intelligence declined to generate this draft. Try simplifying the trip theme or selected interests.")
        } catch LanguageModelSession.GenerationError.decodingFailure {
            throw TripPlanGenerationError.generationFailed("Apple Intelligence returned a draft Trip Planner could not read. Try generating again.")
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            throw TripPlanGenerationError.generationFailed("This trip has too much detail for one generation request. Shorten the theme or selected interests, then try again.")
        } catch {
            throw TripPlanGenerationError.generationFailed("Trip generation failed. Try again in a moment.")
        }
    }

    static let instructions = """
    You are a private trip planning assistant running on device. Create practical, reviewable draft itineraries only. Prefer concrete named places, landmarks, businesses, events, restaurants, neighborhoods, or activities. Do not invent reservations, confirmed bookings, prices, weather, opening hours, event schedules, live availability, street addresses, phone numbers, or claims that require current data.
    """

    static func prompt(for input: TripPlanGenerationInput) -> String {
        let interests = input.selectedInterests.isEmpty ? "No selected interests" : input.selectedInterests.joined(separator: ", ")
        let theme = input.theme.isEmpty ? "No specific theme" : input.theme

        return """
        Generate a structured draft trip plan.

        Destination: \(input.destination)
        Flexible travel window: \(input.travelWindow)
        Trip duration: \(input.durationDays) days
        Traveler count: \(input.travelerCount)
        Trip theme: \(theme)
        Selected interests: \(interests)

        Requirements:
        - Create a short title and a concise overview.
        - Create chronological itinerary items for days 1 through \(input.durationDays).
        - Each item dayNumber must be between 1 and \(input.durationDays).
        - Each item category must be stay, food, activity, or transit.
        - Use specific named places whenever possible, such as "Visit the Louvre Museum" instead of "Visit a museum".
        - Omit vague placeholders such as "Explore downtown", "Go shopping", "Visit a museum", "Have lunch", or "Eat at a restaurant".
        - Generic arrival items are allowed only as the first trip-boundary item. Generic departure items are allowed only as the final trip-boundary item.
        - Include at least one specific named restaurant when the destination, interests, and your general knowledge support a trustworthy candidate.
        - Do not use "Have lunch", "Eat at a restaurant", or similar generic meal text as a substitute for a named restaurant.
        - Keep notes useful for a draft, but avoid addresses unless they are broad area names.
        - Do not include reservations, prices, weather, hours, live schedules, street addresses, phone numbers, or statements that imply confirmed availability.
        """
    }
}

@Generable
struct FoundationModelTripPlan {
    @Guide(description: "A short, specific trip title")
    var title: String

    @Guide(description: "A concise overview of the draft trip plan")
    var overview: String

    @Guide(description: "A chronological collection of itinerary items", .minimumCount(1), .maximumCount(24))
    var items: [FoundationModelItineraryItem]
}

@Generable
struct FoundationModelItineraryItem {
    @Guide(description: "Trip day number. Must fit within the requested trip duration.", .range(1...30))
    var dayNumber: Int

    @Guide(description: "Short concrete name for a named place, business, landmark, event, or boundary transit item. Avoid vague names such as Visit a museum, Explore downtown, Have lunch, or Go shopping.")
    var name: String

    @Guide(description: "Helpful planning note. Do not include prices, hours, live schedules, street addresses, phone numbers, confirmed reservations, or live availability.")
    var notes: String

    @Guide(description: "Supported itinerary category. Food items must name a specific restaurant or food destination.")
    var category: FoundationModelItineraryCategory
}

@Generable
enum FoundationModelItineraryCategory {
    case stay
    case food
    case activity
    case transit

    var itineraryCategory: ItineraryItemCategory {
        switch self {
        case .stay:
            return .stay
        case .food:
            return .food
        case .activity:
            return .activity
        case .transit:
            return .transit
        }
    }
}

enum TripPlanGenerationSanitizer {
    static func draft(from generated: FoundationModelTripPlan, durationDays: Int) -> TripPlanDraft {
        let itemInputs = generated.items.map { item in
            TripPlanDraftItemInput(
                name: item.name,
                notes: item.notes,
                category: item.category.itineraryCategory,
                dayNumber: item.dayNumber
            )
        }

        return draft(
            title: generated.title,
            overview: generated.overview,
            items: itemInputs,
            durationDays: durationDays
        )
    }

    static func draft(
        title: String,
        overview: String,
        items itemInputs: [TripPlanDraftItemInput],
        durationDays: Int
    ) -> TripPlanDraft {
        let duration = max(1, durationDays)
        let generatedItems = itemInputs
            .compactMap { item -> ItineraryItem? in
                let dayNumber = min(max(1, item.dayNumber), duration)
                let cleanedName = clean(item.name)
                guard acceptsGeneratedItem(
                    name: cleanedName,
                    category: item.category,
                    dayNumber: dayNumber,
                    durationDays: duration
                ) else {
                    return nil
                }

                return ItineraryItem(
                    name: cleanedName,
                    notesOrAddress: safeNotes(from: item.notes),
                    category: item.category,
                    dayNumber: dayNumber
                )
            }

        let items = ReviewedTripPlanStore.removingDuplicateDepartureItems(from: generatedItems)
            .sorted { lhs, rhs in
                if lhs.dayNumber == rhs.dayNumber {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }

                return lhs.dayNumber < rhs.dayNumber
            }

        return TripPlanDraft(
            title: clean(title, fallback: "Generated Trip Draft"),
            overview: clean(overview, fallback: "Review these on-device suggestions before saving anything to your trip."),
            items: items
        )
    }

    private static func clean(_ value: String, fallback: String = "") -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }

    private static func safeNotes(from value: String) -> String {
        let cleaned = clean(value)
        guard cleaned.isEmpty == false else { return "" }

        let normalized = normalizedText(cleaned)
        let unsafeFragments = [
            "reservation",
            "reserved",
            "booking",
            "booked",
            "confirmed",
            "open from",
            "opens at",
            "closes at",
            "opening hours",
            "hours are",
            "available at",
            "availability",
            "$",
            "€",
            "£"
        ]

        guard unsafeFragments.contains(where: { normalized.contains($0) }) == false,
              containsPhoneNumber(cleaned) == false,
              containsStreetAddress(cleaned) == false
        else {
            return ""
        }

        return cleaned
    }

    private static func acceptsGeneratedItem(
        name: String,
        category: ItineraryItemCategory,
        dayNumber: Int,
        durationDays: Int
    ) -> Bool {
        guard name.isEmpty == false else { return false }

        if isGenericArrival(name) {
            return category == .transit && dayNumber == 1
        }

        if isGenericDeparture(name) {
            return category == .transit && dayNumber == durationDays
        }

        return isVagueGeneratedItem(name, category: category) == false
    }

    private static func isVagueGeneratedItem(_ name: String, category: ItineraryItemCategory) -> Bool {
        let normalized = normalizedText(name)
        let vagueNames = [
            "activity",
            "arrival",
            "breakfast",
            "dinner",
            "departure",
            "eat at a restaurant",
            "explore",
            "explore downtown",
            "explore the city",
            "food",
            "go shopping",
            "have breakfast",
            "have dinner",
            "have lunch",
            "hotel",
            "lunch",
            "museum",
            "restaurant",
            "shopping",
            "sightseeing",
            "stay",
            "transit",
            "trip idea",
            "visit a landmark",
            "visit a museum",
            "walk around"
        ]

        if vagueNames.contains(normalized) {
            return true
        }

        let vaguePrefixes = [
            "go to a ",
            "have a ",
            "visit a ",
            "visit an "
        ]

        if vaguePrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return true
        }

        if category == .food {
            let genericFoodNames = [
                "breakfast",
                "brunch",
                "dinner",
                "eat at a local restaurant",
                "eat at a restaurant",
                "food market",
                "have breakfast",
                "have brunch",
                "have dinner",
                "have lunch",
                "late dinner",
                "local food",
                "lunch",
                "nearby restaurant",
                "restaurant",
                "street food"
            ]

            return genericFoodNames.contains(normalized)
        }

        return false
    }

    private static func isGenericArrival(_ name: String) -> Bool {
        let normalized = normalizedText(name)
        return normalized == "arrival"
            || normalized == "arrival day"
            || normalized == "arrive"
            || normalized == "arrive and check in"
            || normalized == "check in"
    }

    private static func isGenericDeparture(_ name: String) -> Bool {
        let normalized = normalizedText(name)
        return normalized == "departure"
            || normalized == "departure day"
            || normalized == "departure event"
            || normalized == "depart"
            || normalized == "fly home"
    }

    private static func normalizedText(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private static func containsPhoneNumber(_ value: String) -> Bool {
        value.range(of: #"\+?\d[\d\s().-]{6,}\d"#, options: .regularExpression) != nil
    }

    private static func containsStreetAddress(_ value: String) -> Bool {
        value.range(
            of: #"\b\d{1,6}\s+[A-Za-z0-9.'-]+(?:\s+[A-Za-z0-9.'-]+){0,4}\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Way|Place|Pl|Point|Pt|Piazza|Rue|Via)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}
