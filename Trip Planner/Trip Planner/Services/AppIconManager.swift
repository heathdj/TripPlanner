import Foundation
import UIKit

@MainActor
protocol AppIconManaging {
    var supportsAlternateIcons: Bool { get }
    var currentIconName: String? { get }
    func setIconName(_ iconName: String?) async throws
}

enum AppIconError: LocalizedError, Equatable {
    case alternateIconsUnsupported

    var errorDescription: String? {
        switch self {
        case .alternateIconsUnsupported:
            "This device does not support changing the app icon."
        }
    }
}

@MainActor
struct UIApplicationAppIconManager: AppIconManaging {
    private let application: UIApplication

    init(application: UIApplication) {
        self.application = application
    }

    var supportsAlternateIcons: Bool {
        application.supportsAlternateIcons
    }

    var currentIconName: String? {
        application.alternateIconName
    }

    func setIconName(_ iconName: String?) async throws {
        guard supportsAlternateIcons else {
            throw AppIconError.alternateIconsUnsupported
        }

        guard currentIconName != iconName else { return }

        try await application.setAlternateIconName(iconName)
    }
}
