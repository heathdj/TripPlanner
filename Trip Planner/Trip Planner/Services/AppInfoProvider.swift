import Foundation

struct AppInfo: Equatable, Sendable {
    var displayName: String
    var version: String
    var build: String
    var contactEmail: String
    var privacyURL: URL

    var versionSummary: String {
        "Version \(version) (\(build))"
    }
}

protocol AppInfoProviding {
    var appInfo: AppInfo { get }
}

struct BundleAppInfoProvider: AppInfoProviding {
    private let bundle: Bundle
    private let contactEmail: String
    private let privacyURL: URL

    init(
        bundle: Bundle = .main,
        contactEmail: String = "support@baldtraveler.com",
        privacyURL: URL = URL(string: "https://baldtraveler.com/privacy") ?? URL(filePath: "/privacy")
    ) {
        self.bundle = bundle
        self.contactEmail = contactEmail
        self.privacyURL = privacyURL
    }

    var appInfo: AppInfo {
        AppInfo(
            displayName: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? "Trip Planner",
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            contactEmail: contactEmail,
            privacyURL: privacyURL
        )
    }
}
