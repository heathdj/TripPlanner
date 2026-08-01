import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [TravelSettings]

    let appInfo: AppInfo

    private var travelSettings: TravelSettings? {
        settings.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    GlassEffectContainer(spacing: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            AboutSection(appInfo: appInfo)
                            DefaultsSection(
                                settings: travelSettings,
                                save: saveSettings
                            )
                            SupportSection(appInfo: appInfo)
                        }
                        .padding()
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
            .navigationTitle("Settings")
        }
    }

    private func saveSettings() {
        try? modelContext.save()
    }
}

private struct AboutSection: View {
    let appInfo: AppInfo

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Label(appInfo.displayName, systemImage: "suitcase.fill")
                    .font(.title2.weight(.bold))
                    .fontDesign(.rounded)

                LabeledContent("Version", value: appInfo.versionSummary)
                LabeledContent("Location", value: AppConstants.locationUsageDescription)
            }
        }
    }
}

private struct DefaultsSection: View {
    let settings: TravelSettings?
    let save: () -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trip Defaults")
                    .font(.headline)
                    .fontDesign(.rounded)

                if let settings {
                    Stepper(
                        value: durationBinding(for: settings),
                        in: 1...60,
                        step: 1
                    ) {
                        LabeledContent(
                            "Default duration",
                            value: "\(settings.defaultDurationDays) days"
                        )
                    }

                    Stepper(
                        value: windowBinding(for: settings),
                        in: 1...180,
                        step: 1
                    ) {
                        LabeledContent(
                            "Default window",
                            value: "\(settings.defaultWindowLengthDays) days"
                        )
                    }
                } else {
                    Text("Defaults are created when the app starts.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func durationBinding(for settings: TravelSettings) -> Binding<Int> {
        Binding {
            settings.defaultDurationDays
        } set: { newValue in
            settings.updateDefaultDuration(days: newValue)
            save()
        }
    }

    private func windowBinding(for settings: TravelSettings) -> Binding<Int> {
        Binding {
            settings.defaultWindowLengthDays
        } set: { newValue in
            settings.updateDefaultWindowLength(days: newValue)
            save()
        }
    }
}

private struct SupportSection: View {
    let appInfo: AppInfo

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Support")
                    .font(.headline)
                    .fontDesign(.rounded)

                LabeledContent("Email", value: appInfo.contactEmail)

                Link(destination: appInfo.privacyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.glass)
                .accessibilityHint("Opens the external privacy page")
            }
        }
    }
}
