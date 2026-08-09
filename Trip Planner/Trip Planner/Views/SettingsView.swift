import SwiftUI
import UIKit

struct SettingsView: View {
    let appInfo: AppInfo
    private let iconManager: any AppIconManaging

    @AppStorage(TravelPreferencesStorage.Key.defaultDurationDays) private var defaultDurationDays = TravelSettings.defaultDurationDays
    @AppStorage(TravelPreferencesStorage.Key.defaultWindowLengthDays) private var defaultWindowLengthDays = TravelSettings.defaultWindowLengthDays
    @AppStorage(TravelPreferencesStorage.Key.distanceUnit) private var distanceUnitRawValue = DistanceUnit.kilometers.rawValue
    @AppStorage(TravelPreferencesStorage.Key.nearYouDistanceKilometers) private var nearYouDistanceKilometers = TravelSettings.defaultNearYouDistanceKilometers
    @AppStorage(TravelPreferencesStorage.Key.selectedInterestNames) private var selectedInterestNamesData = TravelPreferencesStorage.defaultSelectedInterestsData
    @AppStorage(TravelPreferencesStorage.Key.customInterestNames) private var customInterestNamesData = TravelPreferencesStorage.defaultCustomInterestsData
    @AppStorage(TravelPreferencesStorage.Key.activationLeadTimeDays) private var activationLeadTimeDays = ActivationPromptEligibilityService.defaultLeadTimeDays
    @AppStorage(TravelPreferencesStorage.Key.activationDatePromptsEnabled) private var activationDatePromptsEnabled = true
    @AppStorage(TravelPreferencesStorage.Key.activationProximityPromptsEnabled) private var activationProximityPromptsEnabled = true
    @AppStorage(TravelPreferencesStorage.Key.activationPromptState) private var activationPromptStateData = TravelPreferencesStorage.defaultActivationPromptStateData

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
                                defaultDurationDays: $defaultDurationDays,
                                defaultWindowLengthDays: $defaultWindowLengthDays,
                                distanceUnitRawValue: $distanceUnitRawValue,
                                nearYouDistanceKilometers: $nearYouDistanceKilometers
                            )
                            ActivationPromptsSettingsSection(
                                activationLeadTimeDays: $activationLeadTimeDays,
                                activationDatePromptsEnabled: $activationDatePromptsEnabled,
                                activationProximityPromptsEnabled: $activationProximityPromptsEnabled,
                                activationPromptStateData: $activationPromptStateData
                            )
                            ActivityInterestsSection(
                                selectedInterestNamesData: $selectedInterestNamesData,
                                customInterestNamesData: $customInterestNamesData
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
        }
        .alert("App Icon Not Changed", isPresented: isShowingIconError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(iconErrorMessage ?? "Choose another icon and try again.")
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
    @Binding var defaultDurationDays: Int
    @Binding var defaultWindowLengthDays: Int
    @Binding var distanceUnitRawValue: String
    @Binding var nearYouDistanceKilometers: Double

    private var distanceUnit: DistanceUnit {
        DistanceUnit(rawValue: distanceUnitRawValue) ?? .kilometers
    }

    private var nearYouDistanceValue: Double {
        distanceUnit.value(fromKilometers: nearYouDistanceKilometers)
    }

    private var nearYouDistanceDisplayString: String {
        "\(nearYouDistanceValue.formatted(.number.precision(.fractionLength(0)))) \(distanceUnit.symbol)"
    }

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trip Defaults")
                    .font(.headline)
                    .fontDesign(.rounded)

                Stepper(
                    value: durationBinding,
                    in: 1...60,
                    step: 1
                ) {
                    LabeledContent(
                        "Default duration",
                        value: "\(defaultDurationDays) days"
                    )
                }

                Stepper(
                    value: windowBinding,
                    in: 1...180,
                    step: 1
                ) {
                    LabeledContent(
                        "Default window",
                        value: "\(defaultWindowLengthDays) days"
                    )
                }

                Picker("Distance units", selection: distanceUnitBinding) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.displayName)
                            .tag(unit)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(
                    value: nearYouDistanceBinding,
                    in: nearYouDistanceRange(for: distanceUnit),
                    step: 5
                ) {
                    LabeledContent(
                        "Near you distance",
                        value: nearYouDistanceDisplayString
                    )
                }
            }
        }
    }

    private var durationBinding: Binding<Int> {
        Binding {
            defaultDurationDays
        } set: { newValue in
            defaultDurationDays = max(1, newValue)
        }
    }

    private var windowBinding: Binding<Int> {
        Binding {
            defaultWindowLengthDays
        } set: { newValue in
            defaultWindowLengthDays = max(1, newValue)
        }
    }

    private var distanceUnitBinding: Binding<DistanceUnit> {
        Binding {
            distanceUnit
        } set: { newValue in
            distanceUnitRawValue = newValue.rawValue
        }
    }

    private var nearYouDistanceBinding: Binding<Double> {
        Binding {
            nearYouDistanceValue
        } set: { newValue in
            nearYouDistanceKilometers = max(1, distanceUnit.kilometers(from: newValue))
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

private struct ActivationPromptsSettingsSection: View {
    @Binding var activationLeadTimeDays: Int
    @Binding var activationDatePromptsEnabled: Bool
    @Binding var activationProximityPromptsEnabled: Bool
    @Binding var activationPromptStateData: String

    private var leadTimeDescription: String {
        activationLeadTimeDays == 1 ? "1 day" : "\(activationLeadTimeDays) days"
    }

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Activation Prompts")
                    .font(.headline)
                    .fontDesign(.rounded)

                Toggle("Date-based prompts", isOn: $activationDatePromptsEnabled)

                Stepper(value: leadTimeBinding, in: 0...14, step: 1) {
                    LabeledContent("Advance notice", value: leadTimeDescription)
                }
                .disabled(activationDatePromptsEnabled == false)

                Text("Use 0 days to prompt only once the trip start date arrives.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Nearby destination prompts", isOn: $activationProximityPromptsEnabled)

                Text("Nearby prompts use your Near You distance and never block date-based prompts when location is unavailable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Reset Suppressed Prompts", systemImage: "arrow.counterclockwise") {
                    resetSuppressedPrompts()
                }
                .buttonStyle(.glass)
                .accessibilityHint("Allows Trip Planner to ask again for trips where Don't Ask Again was selected")
            }
        }
    }

    private var leadTimeBinding: Binding<Int> {
        Binding {
            activationLeadTimeDays
        } set: { newValue in
            activationLeadTimeDays = max(0, newValue)
        }
    }

    private func resetSuppressedPrompts() {
        let state = TravelPreferencesStorage.decodeActivationPromptState(from: activationPromptStateData)
        let updatedState = ActivationPromptEligibilityService.resetAllSuppressions(in: state)
        activationPromptStateData = TravelPreferencesStorage.encodeActivationPromptState(updatedState)
    }
}

private struct ActivityInterestsSection: View {
    @Binding var selectedInterestNamesData: String
    @Binding var customInterestNamesData: String

    @State private var customInterestName = ""

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 10)
    ]

    private var selectedInterestNames: [String] {
        TravelPreferencesStorage.decodeInterests(from: selectedInterestNamesData)
    }

    private var customInterestNames: [String] {
        TravelPreferencesStorage.decodeInterests(from: customInterestNamesData)
    }

    private var visibleSelectedInterests: [String] {
        TravelPreferencesStorage.visibleSelectedInterests(
            selected: selectedInterestNames,
            custom: customInterestNames
        )
    }

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

                selectedInterestsSummary

                VStack(alignment: .leading, spacing: 10) {
                    Text("Suggested")
                        .font(.subheadline.weight(.semibold))

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(ActivityInterestCatalog.builtInInterests, id: \.self) { interest in
                            InterestToggleButton(
                                title: interest,
                                isSelected: TravelPreferencesStorage.isInterestSelected(
                                    interest,
                                    selected: selectedInterestNames
                                )
                            ) {
                                selectedInterestNamesData = TravelPreferencesStorage.encodeInterests(
                                    TravelPreferencesStorage.toggledInterest(
                                        interest,
                                        selected: selectedInterestNames
                                    )
                                )
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
                                addCustomInterest()
                            }

                        Button("Add", systemImage: "plus") {
                            addCustomInterest()
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(trimmedCustomInterest.isEmpty)
                    }

                    if customInterestNames.isEmpty {
                        Text("Add custom interests like pottery, gardens, or jazz clubs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(customInterestNames, id: \.self) { interest in
                                CustomInterestChip(title: interest) {
                                    removeCustomInterest(interest)
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

    private var selectedInterestsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected for generated plans")
                .font(.subheadline.weight(.semibold))

            if visibleSelectedInterests.isEmpty {
                Text("No interests selected yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text(visibleSelectedInterests.joined(separator: ", "))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Selected interests: \(visibleSelectedInterests.joined(separator: ", "))")
            }
        }
    }

    private func addCustomInterest() {
        let interest = trimmedCustomInterest
        guard interest.isEmpty == false else { return }

        let updated = TravelPreferencesStorage.addingCustomInterest(
            interest,
            selected: selectedInterestNames,
            custom: customInterestNames
        )
        selectedInterestNamesData = TravelPreferencesStorage.encodeInterests(updated.selected)
        customInterestNamesData = TravelPreferencesStorage.encodeInterests(updated.custom)
        customInterestName = ""
    }

    private func removeCustomInterest(_ interest: String) {
        let updated = TravelPreferencesStorage.removingCustomInterest(
            interest,
            selected: selectedInterestNames,
            custom: customInterestNames
        )
        selectedInterestNamesData = TravelPreferencesStorage.encodeInterests(updated.selected)
        customInterestNamesData = TravelPreferencesStorage.encodeInterests(updated.custom)
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
