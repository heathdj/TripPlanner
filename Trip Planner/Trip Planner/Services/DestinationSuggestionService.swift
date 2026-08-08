import CoreLocation
import Foundation
import MapKit

struct DestinationSuggestion: Hashable, Identifiable, Sendable {
    let title: String
    let subtitle: String

    var id: String {
        displayText
    }

    var displayText: String {
        [title, subtitle]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }
}

@MainActor
@Observable
final class DestinationSuggestionService: NSObject {
    private let completer: MKLocalSearchCompleter

    var suggestions: [DestinationSuggestion] = []

    init(userLocation: CLLocation? = nil) {
        let completer = MKLocalSearchCompleter()
        self.completer = completer
        super.init()
        completer.delegate = self
        completer.resultTypes = .address

        if let userLocation {
            completer.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 2_000_000,
                longitudinalMeters: 2_000_000
            )
            completer.regionPriority = .default
        }
    }

    func updateQuery(_ query: String) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else {
            completer.queryFragment = ""
            suggestions = []
            return
        }

        completer.queryFragment = normalized
    }

    func clearSuggestions() {
        suggestions = []
        completer.queryFragment = ""
    }
}

extension DestinationSuggestionService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let completions = completer.results.map { completion in
            DestinationSuggestion(
                title: completion.title,
                subtitle: completion.subtitle
            )
        }

        Task { @MainActor in
            var seen = Set<String>()
            suggestions = completions.filter { suggestion in
                seen.insert(suggestion.displayText).inserted
            }
            .prefix(6)
            .map { $0 }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        Task { @MainActor in
            suggestions = []
        }
    }
}
