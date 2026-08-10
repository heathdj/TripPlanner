import CoreLocation
import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]

    @AppStorage(TravelPreferencesStorage.Key.defaultDurationDays) private var defaultDurationDays = TravelSettings.defaultDurationDays
    @AppStorage(TravelPreferencesStorage.Key.defaultWindowLengthDays) private var defaultWindowLengthDays = TravelSettings.defaultWindowLengthDays
    @AppStorage(TravelPreferencesStorage.Key.distanceUnit) private var distanceUnitRawValue = DistanceUnit.kilometers.rawValue
    @AppStorage(TravelPreferencesStorage.Key.nearYouDistanceKilometers) private var nearYouDistanceKilometers = TravelSettings.defaultNearYouDistanceKilometers
    @AppStorage(TravelPreferencesStorage.Key.activationLeadTimeDays) private var activationLeadTimeDays = ActivationPromptEligibilityService.defaultLeadTimeDays
    @AppStorage(TravelPreferencesStorage.Key.activationDatePromptsEnabled) private var activationDatePromptsEnabled = true
    @AppStorage(TravelPreferencesStorage.Key.activationProximityPromptsEnabled) private var activationProximityPromptsEnabled = true
    @AppStorage(TravelPreferencesStorage.Key.activationPromptState) private var activationPromptStateData = TravelPreferencesStorage.defaultActivationPromptStateData

    @State private var locationService = LocationService()
    @State private var presentedTrip: PresentedTrip?
    @State private var isShowingNewTrip = false
    @State private var pendingCreatedTrip: Trip?
    @State private var pendingLifecycleAction: DashboardLifecycleAction?
    @State private var pendingActivationPrompt: ActivationPromptCandidate?
    @State private var didEvaluateLaunchPrompt = false
    @State private var didEvaluateActiveLaunchExperience = false
    @State private var activeLaunchPresentation: ActiveLaunchPresentation?

    private let columns = [
        GridItem(.adaptive(minimum: 280), spacing: 16)
    ]

    private var distanceUnit: DistanceUnit {
        DistanceUnit(rawValue: distanceUnitRawValue) ?? .kilometers
    }

    private var tripGroups: TripGroups {
        TripStore.groupedTrips(
            trips,
            userLocation: locationService.currentLocation,
            nearYouDistanceKilometers: max(1, nearYouDistanceKilometers)
        )
    }

    private var openTrips: [Trip] {
        tripGroups.openTrips
    }

    private var closedTrips: [Trip] {
        tripGroups.closedTrips
    }

    private var activeTrips: [Trip] {
        tripGroups.activeTrips
    }

    private var plannedTrips: [Trip] {
        tripGroups.plannedTrips
    }

    private var activeLaunchEvaluationToken: String {
        trips
            .map { "\($0.id.uuidString)-\($0.status.rawValue)-\($0.updatedAt.timeIntervalSince1970)" }
            .sorted()
            .joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientMapBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if trips.isEmpty {
                            EmptyTripsView(addTrip: { isShowingNewTrip = true })
                        } else {
                            if activeTrips.isEmpty == false {
                                ActiveTripShortcut(
                                    activeTripCount: activeTrips.count,
                                    openActiveTrips: presentActiveTripExperience
                                )
                            }

                            TripSection(
                                title: "Active Trips",
                                emptyTitle: "No active trips",
                                emptySystemImage: "play.slash",
                                emptyMessage: "Trips you start will appear here while they are underway.",
                                trips: activeTrips,
                                columns: columns,
                                selectTrip: selectTrip,
                                requestActivation: requestActivation
                            )

                            NearYouSection(
                                nearbyTrips: tripGroups.nearbyTrips,
                                distanceUnit: distanceUnit,
                                authorizationStatus: locationService.authorizationStatus,
                                hasCurrentLocation: locationService.currentLocation != nil,
                                isRequestingLocation: locationService.isRequestingLocation,
                                errorMessage: locationService.errorMessage,
                                selectTrip: selectTrip,
                                requestActivation: requestActivation,
                                requestLocation: locationService.requestLocationAccess,
                                openSystemSettings: openSystemSettings
                            )

                            TripSection(
                                title: "Planned Trips",
                                emptyTitle: "No planned trips",
                                emptySystemImage: "calendar.badge.clock",
                                emptyMessage: "Trips with exact dates will appear here before they start.",
                                trips: plannedTrips,
                                columns: columns,
                                selectTrip: selectTrip,
                                requestActivation: requestActivation
                            )

                            TripSection(
                                title: "Open Trips",
                                emptyTitle: "No open trips",
                                emptySystemImage: "tray",
                                emptyMessage: "Flexible trip ideas will appear here until you set exact dates.",
                                trips: openTrips,
                                columns: columns,
                                selectTrip: selectTrip,
                                requestActivation: requestActivation
                            )

                            TripSection(
                                title: "Closed Trips",
                                emptyTitle: "No closed trips",
                                emptySystemImage: "checkmark.circle",
                                emptyMessage: "Completed and cancelled trips will appear here for reference.",
                                trips: closedTrips,
                                columns: columns,
                                selectTrip: selectTrip,
                                requestActivation: requestActivation
                            )
                        }
                    }
                    .padding()
                    .frame(maxWidth: 980)
                    .frame(maxWidth: .infinity)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
            .navigationTitle("Trip Planner")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Trip", systemImage: "plus") {
                        isShowingNewTrip = true
                    }
                        .buttonStyle(.glassProminent)
                        .accessibilityHint("Creates a new trip")
                }
            }
        }
        .sheet(item: $activeLaunchPresentation, onDismiss: activeLaunchDidDismiss) { presentation in
            switch presentation {
            case .single(let trip):
                TripDetailView(
                    trip: trip,
                    distanceSummary: distanceSummary(for: trip),
                    userLocation: locationService.currentLocation,
                    nearYouDistanceKilometers: nearYouDistanceKilometers,
                    dismissButtonTitle: "Go to Dashboard",
                    showsProminentDismissButton: true,
                    generatedTripSaved: saveGeneratedTrip
                )
            case .chooser(let trips):
                ActiveTripLaunchChooser(
                    trips: trips,
                    openTrip: { trip in
                        activeLaunchPresentation = .single(trip)
                    },
                    goToDashboard: {
                        activeLaunchPresentation = nil
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingNewTrip, onDismiss: openPendingCreatedTrip) {
            NewTripView(
                defaultDurationDays: defaultDurationDays,
                defaultWindowLengthDays: defaultWindowLengthDays,
                userLocation: locationService.currentLocation
            ) { trip in
                createTrip(trip)
            }
        }
        .sheet(item: $presentedTrip) { presentedTrip in
            TripDetailView(
                trip: presentedTrip.trip,
                distanceSummary: distanceSummary(for: presentedTrip.trip),
                userLocation: locationService.currentLocation,
                nearYouDistanceKilometers: nearYouDistanceKilometers,
                startsGeneratingDraftOnAppear: presentedTrip.startsGeneratingDraftOnAppear,
                generatedTripSaved: saveGeneratedTrip
            )
        }
        .task {
            normalizeMigratedLifecycles()
            locationService.requestAccessOrRefreshLocation()
            evaluateActiveLaunchExperienceIfNeeded()
            evaluateActivationPromptIfNeeded()
        }
        .onChange(of: locationService.currentLocation?.timestamp) {
            evaluateActivationPromptIfNeeded(allowsRepeatEvaluation: true)
        }
        .onChange(of: activeLaunchEvaluationToken) {
            evaluateActiveLaunchExperienceIfNeeded()
        }
        .confirmationDialog(
            pendingLifecycleAction?.title ?? "Update Trip",
            isPresented: Binding {
                pendingLifecycleAction != nil
            } set: { isPresented in
                if isPresented == false {
                    pendingLifecycleAction = nil
                }
            },
            titleVisibility: .visible
        ) {
            if let pendingLifecycleAction {
                Button(pendingLifecycleAction.confirmButtonTitle) {
                    perform(pendingLifecycleAction)
                }
            }

            Button("Keep Trip As Is", role: .cancel) { }
        } message: {
            Text(pendingLifecycleAction?.message ?? "")
        }
        .confirmationDialog(
            pendingActivationPrompt?.title ?? "Make Trip Active?",
            isPresented: Binding {
                pendingActivationPrompt != nil
            } set: { isPresented in
                if isPresented == false {
                    pendingActivationPrompt = nil
                }
            },
            titleVisibility: .visible
        ) {
            if let pendingActivationPrompt {
                Button("Make Active") {
                    activatePromptedTrip(pendingActivationPrompt)
                }

                Button("Not Now", role: .cancel) {
                    dismissActivationPrompt(pendingActivationPrompt)
                }

                Button("Don't Ask Again for This Trip", role: .destructive) {
                    suppressActivationPrompt(pendingActivationPrompt)
                }
            }
        } message: {
            Text(pendingActivationPrompt?.message ?? "")
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func selectTrip(_ trip: Trip) {
        presentedTrip = PresentedTrip(
            trip: trip,
            startsGeneratingDraftOnAppear: false
        )
    }

    private func createTrip(_ trip: Trip) {
        pendingCreatedTrip = trip
    }

    private func requestActivation(_ trip: Trip) {
        pendingLifecycleAction = DashboardLifecycleAction(trip: trip, proposedStartDate: .now)
    }

    private func perform(_ action: DashboardLifecycleAction) {
        do {
            try TripLifecycleService.activate(action.trip, at: action.proposedStartDate)
            try modelContext.save()
        } catch {
            // The detail screen exposes full scheduling controls when the proposed start cannot fit.
            presentedTrip = PresentedTrip(
                trip: action.trip,
                startsGeneratingDraftOnAppear: false
            )
        }
    }

    private func evaluateActivationPromptIfNeeded(allowsRepeatEvaluation: Bool = false) {
        guard pendingActivationPrompt == nil,
              pendingLifecycleAction == nil,
              activeLaunchPresentation == nil,
              presentedTrip == nil,
              isShowingNewTrip == false,
              allowsRepeatEvaluation || didEvaluateLaunchPrompt == false
        else {
            return
        }

        didEvaluateLaunchPrompt = true
        let state = TravelPreferencesStorage.decodeActivationPromptState(from: activationPromptStateData)
        guard let candidate = ActivationPromptEligibilityService.candidate(
            from: trips,
            userLocation: locationService.currentLocation,
            nearYouDistanceKilometers: nearYouDistanceKilometers,
            leadTimeDays: activationLeadTimeDays,
            datePromptsEnabled: activationDatePromptsEnabled,
            proximityPromptsEnabled: activationProximityPromptsEnabled,
            state: state
        ) else {
            return
        }

        activationPromptStateData = TravelPreferencesStorage.encodeActivationPromptState(
            ActivationPromptEligibilityService.recordPromptShown(
                for: candidate.trip.id,
                reasons: candidate.reasons,
                at: .now,
                in: state
            )
        )
        pendingActivationPrompt = candidate
    }

    private func evaluateActiveLaunchExperienceIfNeeded() {
        guard didEvaluateActiveLaunchExperience == false,
              activeLaunchPresentation == nil,
              pendingActivationPrompt == nil,
              pendingLifecycleAction == nil,
              presentedTrip == nil,
              isShowingNewTrip == false
        else {
            return
        }
        guard trips.isEmpty == false else { return }

        let decision = TripStore.activeLaunchDecision(
            for: trips,
            hasAlreadyPresented: didEvaluateActiveLaunchExperience,
            hasBlockingPresentation: false
        )
        let launchActiveTrips = TripStore.sortedLaunchActiveTrips(trips)
        didEvaluateActiveLaunchExperience = true

        switch decision {
        case .none:
            return
        case .single, .chooser:
            activeLaunchPresentation = ActiveLaunchPresentation(trips: launchActiveTrips)
        }
    }

    private func presentActiveTripExperience() {
        let launchActiveTrips = TripStore.sortedLaunchActiveTrips(trips)
        guard launchActiveTrips.isEmpty == false else { return }

        activeLaunchPresentation = ActiveLaunchPresentation(trips: launchActiveTrips)
    }

    private func activeLaunchDidDismiss() {
        evaluateActivationPromptIfNeeded()
    }

    private func activatePromptedTrip(_ candidate: ActivationPromptCandidate) {
        do {
            try TripLifecycleService.activate(candidate.trip, at: candidate.proposedStartDate)
            try modelContext.save()
            pendingActivationPrompt = nil
        } catch {
            presentedTrip = PresentedTrip(
                trip: candidate.trip,
                startsGeneratingDraftOnAppear: false
            )
            pendingActivationPrompt = nil
        }
    }

    private func dismissActivationPrompt(_ candidate: ActivationPromptCandidate) {
        let state = TravelPreferencesStorage.decodeActivationPromptState(from: activationPromptStateData)
        activationPromptStateData = TravelPreferencesStorage.encodeActivationPromptState(
            ActivationPromptEligibilityService.dismiss(
                tripID: candidate.trip.id,
                reasons: candidate.reasons,
                at: .now,
                in: state
            )
        )
        pendingActivationPrompt = nil
    }

    private func suppressActivationPrompt(_ candidate: ActivationPromptCandidate) {
        let state = TravelPreferencesStorage.decodeActivationPromptState(from: activationPromptStateData)
        activationPromptStateData = TravelPreferencesStorage.encodeActivationPromptState(
            ActivationPromptEligibilityService.suppress(
                tripID: candidate.trip.id,
                reasons: candidate.reasons,
                at: .now,
                in: state
            )
        )
        pendingActivationPrompt = nil
    }

    private func saveGeneratedTrip(_ trip: Trip) {
        let tripID = trip.id
        let descriptor = FetchDescriptor<Trip>(
            predicate: #Predicate { savedTrip in
                savedTrip.id == tripID
            }
        )

        let fetchedTrips = (try? modelContext.fetch(descriptor)) ?? []
        let savedTrip = fetchedTrips.first ?? trip
        TripLifecycleService.normalizeMigratedLifecycle(for: savedTrip)
        savedTrip.updatedAt = .now
        savedTrip.itineraryItems = TripStore.sortedItineraryItems(savedTrip.itineraryItems)
        savedTrip.updateProgressFromItinerary()

        if fetchedTrips.isEmpty {
            modelContext.insert(savedTrip)
        }

        try? modelContext.save()
        presentedTrip = nil
    }

    private func normalizeMigratedLifecycles() {
        trips.forEach { TripLifecycleService.normalizeMigratedLifecycle(for: $0) }
        try? modelContext.save()
    }

    private func openPendingCreatedTrip() {
        guard let trip = pendingCreatedTrip else { return }

        pendingCreatedTrip = nil
        presentedTrip = PresentedTrip(
            trip: trip,
            startsGeneratingDraftOnAppear: true
        )
    }

    private func distanceSummary(for trip: Trip) -> String? {
        tripGroups.nearbyTrips
            .first { $0.trip.id == trip.id }
            .map { distanceUnit.formattedDistance(meters: $0.distanceMeters) }
    }
}

private struct PresentedTrip: Identifiable {
    let trip: Trip
    let startsGeneratingDraftOnAppear: Bool

    var id: String {
        "\(trip.id)-\(startsGeneratingDraftOnAppear)"
    }
}

private enum ActiveLaunchPresentation: Identifiable {
    case single(Trip)
    case chooser([Trip])

    init(trips: [Trip]) {
        if let onlyTrip = trips.first,
           trips.count == 1 {
            self = .single(onlyTrip)
        } else {
            self = .chooser(trips)
        }
    }

    var id: String {
        switch self {
        case .single(let trip):
            return "active-\(trip.id)"
        case .chooser(let trips):
            return "active-chooser-\(trips.map(\.id.uuidString).joined(separator: "-"))"
        }
    }
}

private struct DashboardLifecycleAction: Identifiable {
    let trip: Trip
    let proposedStartDate: Date

    var id: UUID {
        trip.id
    }

    var title: String {
        "Make Trip Active?"
    }

    var confirmButtonTitle: String {
        "Make Active"
    }

    var message: String {
        if trip.exactStartDate == nil {
            return "This will set the exact start date to \(proposedStartDate.formatted(date: .abbreviated, time: .omitted)) and move the trip to Active Trips."
        }

        return "This moves \(trip.title) to Active Trips. You can have more than one active trip."
    }
}

private struct ActiveTripShortcut: View {
    let activeTripCount: Int
    let openActiveTrips: () -> Void

    var body: some View {
        Button {
            openActiveTrips()
        } label: {
            Label(title, systemImage: "play.circle.fill")
                .font(.headline)
                .fontDesign(.rounded)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .buttonStyle(.glassProminent)
        .accessibilityHint("Opens the active trip launch experience without changing trip state")
    }

    private var title: String {
        activeTripCount == 1 ? "Open Active Trip" : "Choose Active Trip"
    }
}

private struct ActiveTripLaunchChooser: View {
    @Environment(\.dismiss) private var dismiss

    let trips: [Trip]
    let openTrip: (Trip) -> Void
    let goToDashboard: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientMapBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("\(trips.count) Active Trips", systemImage: "play.circle.fill")
                                .font(.title2.weight(.bold))
                                .fontDesign(.rounded)

                            Text("Choose the trip you want to continue, or go to the dashboard to see everything.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(trips) { trip in
                                Button {
                                    openTrip(trip)
                                } label: {
                                    TripSummaryCard(trip: trip.summary())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(trip.title), \(trip.location), \(trip.progressAccessibilityValue)")
                                .accessibilityHint("Opens this active trip")
                            }
                        }

                        Button("Go to Dashboard", systemImage: "rectangle.grid.2x2.fill") {
                            goToDashboard()
                            dismiss()
                        }
                        .buttonStyle(.glassProminent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHint("Dismisses this chooser without changing active trips")
                    }
                    .padding()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
            .navigationTitle("Active Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Go to Dashboard") {
                        goToDashboard()
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct EmptyTripsView: View {
    let addTrip: () -> Void

    var body: some View {
        GlassPanel {
            ContentUnavailableView {
                Label("No Trips Yet", systemImage: "map")
            } description: {
                Text("Create your first trip to start planning dates, places, and itinerary items.")
            } actions: {
                Button("Add Trip", systemImage: "plus") {
                    addTrip()
                }
                .buttonStyle(.glassProminent)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct NearYouSection: View {
    let nearbyTrips: [NearbyTrip]
    let distanceUnit: DistanceUnit
    let authorizationStatus: CLAuthorizationStatus
    let hasCurrentLocation: Bool
    let isRequestingLocation: Bool
    let errorMessage: String?
    let selectTrip: (Trip) -> Void
    let requestActivation: (Trip) -> Void
    let requestLocation: () -> Void
    let openSystemSettings: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 280), spacing: 16)
    ]

    private var isDeniedOrRestricted: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    private var canUseLocation: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Near You")
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)

            if nearbyTrips.isEmpty {
                locationStatusPanel
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(nearbyTrips) { nearbyTrip in
                        TripCardButton(
                            trip: nearbyTrip.trip,
                            distanceSummary: distanceUnit.formattedDistance(meters: nearbyTrip.distanceMeters),
                            selectTrip: selectTrip,
                            requestActivation: requestActivation
                        )
                    }
                }
            }
        }
    }

    private var locationStatusPanel: some View {
        GlassPanel {
            ContentUnavailableView {
                Label(statusTitle, systemImage: statusIcon)
            } description: {
                VStack(spacing: 8) {
                    Text(statusMessage)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                    }
                }
            } actions: {
                locationStatusActions
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var locationStatusActions: some View {
        if canUseLocation {
            if isRequestingLocation {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Finding nearby trips")
            }
        } else if isDeniedOrRestricted {
            Button("Open Settings", systemImage: "gearshape") {
                openSystemSettings()
            }
            .buttonStyle(.glassProminent)
        } else {
            Button(requestButtonTitle, systemImage: "location.fill") {
                requestLocation()
            }
            .buttonStyle(.glassProminent)
            .disabled(isRequestingLocation)
        }
    }

    private var statusTitle: String {
        if isDeniedOrRestricted {
            return "Location access is off"
        }

        if canUseLocation {
            return hasCurrentLocation ? "No nearby current trips" : "Finding nearby trips"
        }

        return "Find trips near you"
    }

    private var statusMessage: String {
        if isDeniedOrRestricted {
            return "Trip Planner can still show your trips by lifecycle state. Enable location access in Settings to promote nearby current trips here."
        }

        if canUseLocation {
            if hasCurrentLocation {
                return "Current trips outside your Near You distance stay in their lifecycle sections."
            }

            return "Trip Planner has location access while you use the app and is checking for nearby current trips."
        }

        return "Use your current location to promote nearby current trips into this section."
    }

    private var statusIcon: String {
        isDeniedOrRestricted ? "location.slash.fill" : "location.fill"
    }

    private var requestButtonTitle: String {
        isRequestingLocation ? "Finding Location" : "Enable Location"
    }
}

private struct TripSection: View {
    let title: String
    let emptyTitle: String
    let emptySystemImage: String
    let emptyMessage: String
    let trips: [Trip]
    let columns: [GridItem]
    let selectTrip: (Trip) -> Void
    let requestActivation: (Trip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)

            if trips.isEmpty {
                GlassPanel {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: emptySystemImage,
                        description: Text(emptyMessage)
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(trips) { trip in
                        TripCardButton(
                            trip: trip,
                            selectTrip: selectTrip,
                            requestActivation: requestActivation
                        )
                    }
                }
            }
        }
    }
}

private struct TripCardButton: View {
    let trip: Trip
    var distanceSummary: String? = nil
    let selectTrip: (Trip) -> Void
    let requestActivation: (Trip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                selectTrip(trip)
            } label: {
                TripSummaryCard(
                    trip: trip.summary(),
                    distanceSummary: distanceSummary
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Opens trip details")

            if canActivate {
                Button("Make Active", systemImage: "play.fill") {
                    requestActivation(trip)
                }
                .buttonStyle(.glassProminent)
                .accessibilityHint(activationHint)
            }
        }
    }

    private var canActivate: Bool {
        trip.status == .open || trip.status == .planned
    }

    private var activationHint: String {
        if trip.exactStartDate == nil {
            return "Asks you to confirm today's date as the trip start before moving this trip to Active Trips"
        }

        return "Moves this trip to Active Trips after confirmation"
    }

    private var accessibilityLabel: String {
        [
            trip.title,
            trip.location,
            trip.windowDisplayString,
            trip.durationDisplayString,
            trip.travelerDisplayString,
            trip.progressAccessibilityValue,
            distanceSummary
        ]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

private struct TripSummaryCard: View {
    let trip: TripSummary
    var distanceSummary: String? = nil

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: trip.status.systemImage)
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular.tint(.green.opacity(0.2)), in: .circle)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.title)
                            .font(.headline)
                            .fontDesign(.rounded)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(trip.location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(trip.highlight)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    if let distanceSummary {
                        Label(distanceSummary, systemImage: "location.fill")
                    }
                    Label(trip.dateRange, systemImage: "calendar")
                    Label(trip.durationSummary, systemImage: "clock")
                    Label(trip.travelerSummary, systemImage: "person.2.fill")
                    Label(trip.startDateSummary, systemImage: "arrow.triangle.branch")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Progress")
                            .font(.caption.weight(.semibold))

                        Spacer()

                        Text(trip.progressSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: trip.progressFraction)
                        .tint(.teal)
                        .accessibilityLabel("Trip progress")
                        .accessibilityValue(progressAccessibilityValue)
                }

                HStack {
                    Text(statusBadgeText)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.tint(.orange.opacity(0.18)), in: .capsule)

                    Spacer(minLength: 12)

                    Text("\(trip.plannedItemCount) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statusBadgeText: String {
        if trip.status == .closed,
           let closedOutcomeSummary = trip.closedOutcomeSummary {
            return closedOutcomeSummary
        }

        return trip.status.rawValue
    }

    private var progressAccessibilityValue: String {
        let percentage = Int((trip.progressFraction * 100).rounded())
        return "\(trip.progressSummary), \(percentage) percent"
    }
}

private struct AmbientMapBackground: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)

            LinearGradient(
                colors: [
                    Color.teal.opacity(0.24),
                    Color.green.opacity(0.16),
                    Color.blue.opacity(0.12),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            MapGridPattern()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                .padding(-80)
        }
    }
}

struct MapGridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 72

        stride(from: rect.minX, through: rect.maxX, by: spacing).forEach { x in
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x + 36, y: rect.maxY))
        }

        stride(from: rect.minY, through: rect.maxY, by: spacing).forEach { y in
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y + 28))
        }

        return path
    }
}
