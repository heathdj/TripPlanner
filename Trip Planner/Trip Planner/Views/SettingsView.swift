import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [TravelSettings]

    let appInfo: AppInfo
    private let iconManager: any AppIconManaging

    @State private var selectedIconName: String?
    @State private var iconErrorMessage: String?

    @MainActor
    init(
        appInfo: AppInfo,
        iconManager: (any AppIconManaging)? = nil
    ) {
        self.appInfo = appInfo
        self.iconManager = iconManager ?? UIApplicationAppIconManager(application: .shared)
    }

    private var travelSettings: TravelSettings? {
        settings.first
    }

    private var isShowingIconError: Binding<Bool> {
        Binding {
            iconErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                iconErrorMessage = nil
            }
        }
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
                            AppIconSection(
                                selectedIconName: $selectedIconName,
                                errorMessage: $iconErrorMessage,
                                iconManager: iconManager
                            )
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
        .task {
            selectedIconName = iconManager.currentIconName
            ensureTravelSettings()
        }
        .alert("App Icon Not Changed", isPresented: isShowingIconError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(iconErrorMessage ?? "Choose another icon and try again.")
        }
    }

    private func saveSettings() {
        try? modelContext.save()
    }

    private func ensureTravelSettings() {
        guard settings.isEmpty else { return }

        modelContext.insert(TravelSettings())
        saveSettings()
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

private struct AppIconSection: View {
    @Binding var selectedIconName: String?
    @Binding var errorMessage: String?

    let iconManager: any AppIconManaging

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("App Icon")
                        .font(.headline)
                        .fontDesign(.rounded)

                    Spacer()

                    if iconManager.supportsAlternateIcons == false {
                        Label("Unsupported", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(AppIconOption.all) { option in
                        Button {
                            Task {
                                await select(option)
                            }
                        } label: {
                            AppIconChoiceLabel(
                                option: option,
                                isSelected: option.iconName == selectedIconName
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(iconManager.supportsAlternateIcons == false)
                        .accessibilityLabel(option.displayName)
                        .accessibilityValue(option.iconName == selectedIconName ? "Selected" : "Not selected")
                        .accessibilityHint("Changes the app icon")
                    }
                }
            }
        }
    }

    private func select(_ option: AppIconOption) async {
        do {
            try await iconManager.setIconName(option.iconName)
            selectedIconName = iconManager.currentIconName
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AppIconChoiceLabel: View {
    let option: AppIconOption
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                AppIconPreview(option: option)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .teal)
                        .padding(6)
                        .accessibilityHidden(true)
                }
            }

            Text(option.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .glassEffect(
            isSelected ? .regular.tint(.teal.opacity(0.22)) : .regular,
            in: .rect(cornerRadius: 18)
        )
    }
}

private struct AppIconPreview: View {
    let option: AppIconOption

    var body: some View {
        Group {
            if let image = UIImage(named: option.previewImageName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "map.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.teal.gradient)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
        .accessibilityLabel(option.accessibilityDescription)
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

                    Picker("Distance units", selection: distanceUnitBinding(for: settings)) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.displayName)
                                .tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(
                        value: nearYouDistanceBinding(for: settings),
                        in: nearYouDistanceRange(for: settings.distanceUnit),
                        step: 5
                    ) {
                        LabeledContent(
                            "Near you distance",
                            value: settings.nearYouDistanceDisplayString
                        )
                    }
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

    private func distanceUnitBinding(for settings: TravelSettings) -> Binding<DistanceUnit> {
        Binding {
            settings.distanceUnit
        } set: { newValue in
            settings.updateDistanceUnit(newValue)
            save()
        }
    }

    private func nearYouDistanceBinding(for settings: TravelSettings) -> Binding<Double> {
        Binding {
            settings.nearYouDistanceValue
        } set: { newValue in
            settings.updateNearYouDistance(value: newValue, unit: settings.distanceUnit)
            save()
        }
    }

    private func nearYouDistanceRange(for unit: DistanceUnit) -> ClosedRange<Double> {
        switch unit {
        case .kilometers:
            return 5...500
        case .miles:
            return 5...300
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
