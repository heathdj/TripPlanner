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

enum TripPlanGenerationStatus: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unavailable

    var isAvailable: Bool {
        self == .available
    }

    var title: String {
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

    var message: String {
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
    You are a private trip planning assistant running on device. Create practical, reviewable draft itineraries only. Do not invent reservations, confirmed bookings, prices, weather, opening hours, event schedules, live availability, or claims that require current data.
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
        - Keep notes useful for a draft, but avoid addresses unless they are broad area names.
        - Do not include reservations, prices, weather, hours, live schedules, or statements that imply confirmed availability.
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

    @Guide(description: "Short name for this stop or activity")
    var name: String

    @Guide(description: "Helpful planning note. Do not include prices, hours, live schedules, or confirmed reservations.")
    var notes: String

    @Guide(description: "Supported itinerary category")
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
            .map { item in
                ItineraryItem(
                    name: clean(item.name, fallback: "Trip idea"),
                    notesOrAddress: clean(item.notes),
                    category: item.category,
                    dayNumber: min(max(1, item.dayNumber), duration)
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
}
