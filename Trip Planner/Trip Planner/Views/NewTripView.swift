import SwiftUI

struct NewTripView: View {
    @Environment(\.dismiss) private var dismiss

    let settings: TravelSettings?
    let saveTrip: (Trip) -> Void

    @State private var title = ""
    @State private var destination = ""
    @State private var windowStartDate: Date
    @State private var windowEndDate: Date
    @State private var durationDays: Int
    @State private var travelerCount = 1
    @State private var theme = ""

    init(
        settings: TravelSettings?,
        saveTrip: @escaping (Trip) -> Void
    ) {
        self.settings = settings
        self.saveTrip = saveTrip

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: .now)
        let defaultDurationDays = settings?.defaultDurationDays ?? TravelSettings.defaultDurationDays
        let defaultWindowLengthDays = settings?.defaultWindowLengthDays ?? TravelSettings.defaultWindowLengthDays
        let endDate = calendar.date(byAdding: .day, value: max(0, defaultWindowLengthDays - 1), to: startDate) ?? startDate

        _windowStartDate = State(initialValue: startDate)
        _windowEndDate = State(initialValue: endDate)
        _durationDays = State(initialValue: defaultDurationDays)
    }

    private var trimmedDestination: String {
        destination.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedTheme: String {
        theme.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreateTrip: Bool {
        trimmedDestination.isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Where") {
                    TextField("Destination", text: $destination)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    TextField("Trip name", text: $title)
                        .textInputAutocapitalization(.words)
                }

                Section("When") {
                    DatePicker("Window starts", selection: $windowStartDate, displayedComponents: .date)
                    DatePicker("Window ends", selection: $windowEndDate, in: windowStartDate..., displayedComponents: .date)

                    Stepper(value: $durationDays, in: 1...60, step: 1) {
                        LabeledContent("Trip duration", value: durationDays == 1 ? "1 day" : "\(durationDays) days")
                    }
                }

                Section("Who") {
                    Stepper(value: $travelerCount, in: 1...20, step: 1) {
                        LabeledContent("Travelers", value: travelerCount == 1 ? "1 traveler" : "\(travelerCount) travelers")
                    }
                }

                Section("Generated Draft Context") {
                    TextField("Theme or notes", text: $theme, axis: .vertical)
                        .lineLimit(3...5)
                        .textInputAutocapitalization(.sentences)

                    Text("After this trip is created, Trip Planner will open its detail screen and start an on-device generated draft when Apple Intelligence is available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: windowStartDate) {
                if windowEndDate < windowStartDate {
                    windowEndDate = windowStartDate
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTrip()
                    }
                    .disabled(canCreateTrip == false)
                }
            }
        }
    }

    private func createTrip() {
        guard canCreateTrip else { return }

        let trip = Trip(
            title: trimmedTitle.isEmpty ? trimmedDestination : trimmedTitle,
            location: trimmedDestination,
            windowStartDate: windowStartDate,
            windowEndDate: windowEndDate,
            durationDays: durationDays,
            status: .open,
            highlight: trimmedTheme.isEmpty ? "Ready for an on-device generated draft." : trimmedTheme,
            travelerCount: travelerCount
        )

        saveTrip(trip)
        dismiss()
    }
}
