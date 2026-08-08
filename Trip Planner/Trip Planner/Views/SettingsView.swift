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
    @State private var settingsErrorMessage: String?

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
                            ActivityInterestsSection(
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
        .alert("Settings Not Saved", isPresented: isShowingSettingsError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(settingsErrorMessage ?? "Try changing the setting again.")
        }
    }

    private func saveSettings() {
        do {
            try modelContext.save()
        } catch {
            settingsErrorMessage = "Trip Planner could not save settings. Try changing the setting again."
        }
    }

    private func ensureTravelSettings() {
        do {
            _ = try TravelSettingsStore.settings(in: modelContext)
        } catch {
            settingsErrorMessage = "Trip Planner could not load saved settings."
        }
    }

    private var isShowingSettingsError: Binding<Bool> {
        Binding {
            settingsErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                settingsErrorMessage = nil
            }
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

private struct ActivityInterestsSection: View {
    let settings: TravelSettings?
    let save: () -> Void

    @State private var customInterestName = ""

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 10)
    ]

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Activity Interests")
                    .font(.headline)
                    .fontDesign(.rounded)

                Text("Interests stay on this device and are shared with the model only when you ask Trip Planner to generate a plan.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let settings {
                    selectedInterestsSummary(for: settings)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Suggested")
                            .font(.subheadline.weight(.semibold))

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(ActivityInterestCatalog.builtInInterests, id: \.self) { interest in
                                InterestToggleButton(
                                    title: interest,
                                    isSelected: settings.isInterestSelected(interest)
                                ) {
                                    settings.toggleInterest(interest)
                                    save()
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Custom")
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 10) {
                            TextField("Add an interest", text: $customInterestName)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    addCustomInterest(to: settings)
                                }

                            Button("Add", systemImage: "plus") {
                                addCustomInterest(to: settings)
                            }
                            .buttonStyle(.glassProminent)
                            .disabled(trimmedCustomInterest.isEmpty)
                        }

                        if settings.customInterestNames.isEmpty {
                            Text("Add custom interests like pottery, gardens, or jazz clubs.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                                ForEach(settings.customInterestNames, id: \.self) { interest in
                                    CustomInterestChip(title: interest) {
                                        settings.removeCustomInterest(interest)
                                        save()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var trimmedCustomInterest: String {
        customInterestName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func selectedInterestsSummary(for settings: TravelSettings) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected for generated plans")
                .font(.subheadline.weight(.semibold))

            if settings.visibleSelectedInterests.isEmpty {
                Text("No interests selected yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text(settings.visibleSelectedInterests.joined(separator: ", "))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Selected interests: \(settings.visibleSelectedInterests.joined(separator: ", "))")
            }
        }
    }

    private func addCustomInterest(to settings: TravelSettings) {
        let interest = trimmedCustomInterest
        guard interest.isEmpty == false else { return }

        settings.addCustomInterest(interest)
        customInterestName = ""
        save()
    }
}

private struct InterestToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Label(title, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(.teal.opacity(0.24)) : .regular,
            in: .rect(cornerRadius: 12)
        )
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Toggles this interest for generated trip plans")
    }
}

private struct CustomInterestChip: View {
    let title: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)

            Spacer(minLength: 4)

            Button("Remove", systemImage: "xmark.circle.fill") {
                remove()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(title)")
            .accessibilityHint("Removes this custom interest")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(.teal.opacity(0.14)), in: .rect(cornerRadius: 12))
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
