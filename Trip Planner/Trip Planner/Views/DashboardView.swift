import CoreLocation
import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @Query private var trips: [Trip]
    @Query private var settings: [TravelSettings]

    @State private var locationService = LocationService()
    @State private var selectedTrip: Trip?

    private let columns = [
        GridItem(.adaptive(minimum: 280), spacing: 16)
    ]

    private var distanceUnit: DistanceUnit {
        settings.first?.distanceUnit ?? .kilometers
    }

    private var nearYouDistanceKilometers: Double {
        settings.first?.nearYouDistanceKilometers ?? TravelSettings.defaultNearYouDistanceKilometers
    }

    private var tripGroups: TripGroups {
        TripStore.groupedTrips(
            trips,
            userLocation: locationService.currentLocation,
            nearYouDistanceKilometers: nearYouDistanceKilometers
        )
    }

    private var openTrips: [Trip] {
        tripGroups.openTrips
    }

    private var closedTrips: [Trip] {
        tripGroups.closedTrips
    }

    private var openTripCount: Int {
        trips.filter { $0.status == .open }.count
    }

    private var plannedItemTotal: Int {
        trips.reduce(0) { total, trip in
            total + trip.plannedItemCount
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientMapBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HeroPanel(
                            nextTrip: tripGroups.nearbyTrips.first?.trip ?? openTrips.first,
                            openTripCount: openTripCount,
                            plannedItemTotal: plannedItemTotal
                        )

                        NearYouSection(
                            nearbyTrips: tripGroups.nearbyTrips,
                            distanceUnit: distanceUnit,
                            authorizationStatus: locationService.authorizationStatus,
                            isRequestingLocation: locationService.isRequestingLocation,
                            errorMessage: locationService.errorMessage,
                            selectTrip: selectTrip,
                            requestLocation: locationService.requestLocationAccess,
                            openSystemSettings: openSystemSettings
                        )

                        TripSection(
                            title: "Open Trips",
                            emptyTitle: "No open trips",
                            trips: openTrips,
                            columns: columns,
                            selectTrip: selectTrip
                        )

                        TripSection(
                            title: "Closed Trips",
                            emptyTitle: "No closed trips",
                            trips: closedTrips,
                            columns: columns,
                            selectTrip: selectTrip
                        )
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
                    Button("Add Trip", systemImage: "plus") { }
                        .buttonStyle(.glassProminent)
                        .accessibilityHint("Creates a new trip")
                }
            }
        }
        .sheet(item: $selectedTrip) { trip in
            TripDetailView(
                trip: trip,
                distanceSummary: distanceSummary(for: trip)
            )
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func selectTrip(_ trip: Trip) {
        selectedTrip = trip
    }

    private func distanceSummary(for trip: Trip) -> String? {
        tripGroups.nearbyTrips
            .first { $0.trip.id == trip.id }
            .map { distanceUnit.formattedDistance(meters: $0.distanceMeters) }
    }
}

private struct HeroPanel: View {
    let nextTrip: Trip?
    let openTripCount: Int
    let plannedItemTotal: Int

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            GlassPanel(cornerRadius: 28) {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Flexible Travel Windows", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("Plan the trip length separately from when it can happen.")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .fixedSize(horizontal: false, vertical: true)

                    if let nextTrip {
                        Text(nextTrip.highlight)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 12) {
                        StatPill(
                            title: "Open Trips",
                            value: "\(openTripCount)",
                            systemImage: "suitcase.rolling.fill"
                        )

                        StatPill(
                            title: "Planned Items",
                            value: "\(plannedItemTotal)",
                            systemImage: "list.bullet.clipboard.fill"
                        )
                    }
                }
            }
        }
    }
}

private struct NearYouSection: View {
    let nearbyTrips: [NearbyTrip]
    let distanceUnit: DistanceUnit
    let authorizationStatus: CLAuthorizationStatus
    let isRequestingLocation: Bool
    let errorMessage: String?
    let selectTrip: (Trip) -> Void
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
                            selectTrip: selectTrip
                        )
                    }
                }
            }
        }
    }

    private var locationStatusPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Label(statusTitle, systemImage: statusIcon)
                    .font(.headline)
                    .fontDesign(.rounded)

                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isDeniedOrRestricted {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusTitle: String {
        if isDeniedOrRestricted {
            return "Location access is off"
        }

        if canUseLocation {
            return "No nearby open trips"
        }

        return "Find trips near you"
    }

    private var statusMessage: String {
        if isDeniedOrRestricted {
            return "Trip Planner can still show Open and Closed trips. Enable location access in Settings to promote nearby open trips here."
        }

        if canUseLocation {
            return "Open trips outside your Near You distance stay in the Open Trips section."
        }

        return "Use your current location to promote nearby open trips into this section."
    }

    private var statusIcon: String {
        isDeniedOrRestricted ? "location.slash.fill" : "location.fill"
    }

    private var requestButtonTitle: String {
        isRequestingLocation ? "Finding Location" : "Use My Location"
    }
}

private struct TripSection: View {
    let title: String
    let emptyTitle: String
    let trips: [Trip]
    let columns: [GridItem]
    let selectTrip: (Trip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)

            if trips.isEmpty {
                GlassPanel {
                    Label(emptyTitle, systemImage: "tray")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(trips) { trip in
                        TripCardButton(
                            trip: trip,
                            selectTrip: selectTrip
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

    var body: some View {
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
    }

    private var accessibilityLabel: String {
        [
            trip.title,
            trip.location,
            trip.windowDisplayString,
            trip.durationDisplayString,
            trip.travelerDisplayString,
            trip.progressDisplayString,
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
                        .accessibilityValue(trip.progressSummary)
                }

                HStack {
                    Text(trip.status.rawValue)
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
