import SwiftUI

struct SettingsView: View {
    let appInfo: AppInfo

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    GlassEffectContainer(spacing: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            AboutSection(appInfo: appInfo)
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
