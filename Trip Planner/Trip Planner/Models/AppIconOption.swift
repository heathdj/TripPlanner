import Foundation

struct AppIconOption: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let iconName: String?
    let previewImageName: String
    let accessibilityDescription: String

    var plistIconName: String? { iconName }

    static let all: [AppIconOption] = [
        AppIconOption(
            id: "mapPins",
            displayName: "Map Pins",
            iconName: nil,
            previewImageName: "MapPins",
            accessibilityDescription: "Default blue map pins icon"
        ),
        AppIconOption(
            id: "compassSpark",
            displayName: "Compass Spark",
            iconName: "AppIcon-CompassSpark",
            previewImageName: "CompassSpark",
            accessibilityDescription: "Blue compass spark alternate icon"
        ),
        AppIconOption(
            id: "layeredItinerary",
            displayName: "Layered Itinerary",
            iconName: "AppIcon-LayeredItinerary",
            previewImageName: "LayeredItinerary",
            accessibilityDescription: "Layered itinerary alternate icon"
        ),
        AppIconOption(
            id: "routeCase",
            displayName: "Route Case",
            iconName: "AppIcon-RouteCase",
            previewImageName: "RouteCase",
            accessibilityDescription: "Route case alternate icon"
        )
    ]

    static func option(for iconName: String?) -> AppIconOption {
        all.first { $0.iconName == iconName } ?? all[0]
    }
}
