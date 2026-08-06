import SwiftData
import SwiftUI

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var reviewedPlans: [ReviewedTripPlan]

    let trip: Trip
    var distanceSummary: String?
    var openDirections: (ItineraryItem, Trip) -> Void = AppleMapsDirectionsService.openDirections

    private var savedPlan: ReviewedTripPlan? {
        reviewedPlans
            .filter { $0.tripID == trip.id }
            .sorted { $0.reviewedAt > $1.reviewedAt }
            .first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        DetailHero(trip: trip, distanceSummary: distanceSummary)
                        TripFactsGrid(trip: trip, distanceSummary: distanceSummary)
                        SavedPlanSection(plan: savedPlan)
                        ItinerarySection(
                            trip: trip,
                            items: trip.itineraryItems,
                            openDirections: openDirections
                        )
                    }
                    .padding()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
            .navigationTitle(trip.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct DetailHero: View {
    let trip: Trip
    let distanceSummary: String?

    var body: some View {
        GlassPanel(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(heroGradient)
                        .frame(minHeight: 190)
                        .overlay {
                            MapGridPattern()
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                .padding(-40)
                        }
                        .clipShape(.rect(cornerRadius: 24))

                    VStack(alignment: .leading, spacing: 8) {
                        Label(trip.status.rawValue, systemImage: trip.status.systemImage)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .glassEffect(.regular.tint(.white.opacity(0.22)), in: .capsule)

                        Text(trip.title)
                            .font(.largeTitle.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(trip.location)
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                }

                Text(trip.highlight)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Plan progress")
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Text(trip.progressDisplayString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: trip.progressFraction)
                        .tint(.teal)
                        .accessibilityLabel("Plan progress")
                        .accessibilityValue(trip.progressDisplayString)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.title), \(trip.location), \(trip.status.rawValue), \(trip.progressDisplayString)")
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.teal,
                Color.blue.opacity(0.82),
                Color.green.opacity(0.78)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct TripFactsGrid: View {
    let trip: Trip
    let distanceSummary: String?

    private var facts: [TripFact] {
        var values = [
            TripFact(title: "Travel window", value: trip.windowDisplayString, systemImage: "calendar"),
            TripFact(title: "Trip duration", value: trip.durationDisplayString, systemImage: "clock"),
            TripFact(title: "Travelers", value: trip.travelerDisplayString, systemImage: "person.2.fill"),
            TripFact(title: "Starts", value: trip.startDateDisplayString, systemImage: "arrow.triangle.branch")
        ]

        if let distanceSummary {
            values.insert(
                TripFact(title: "Nearby distance", value: distanceSummary, systemImage: "location.fill"),
                at: 0
            )
        }

        return values
    }

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Trip Facts")
                    .font(.headline)
                    .fontDesign(.rounded)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(facts) { fact in
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: fact.systemImage)
                                .font(.headline)
                                .foregroundStyle(.teal)
                                .accessibilityHidden(true)

                            Text(fact.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(fact.value)
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .glassEffect(.regular.tint(.teal.opacity(0.12)), in: .rect(cornerRadius: 14))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

private struct TripFact: Identifiable {
    let title: String
    let value: String
    let systemImage: String

    var id: String {
        title
    }
}

private struct SavedPlanSection: View {
    let plan: ReviewedTripPlan?

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Saved Plan")
                    .font(.headline)
                    .fontDesign(.rounded)

                if let plan {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.title)
                            .font(.subheadline.weight(.semibold))

                        Text(plan.notes)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Label(plan.reviewedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                } else {
                    Label("No saved plan yet", systemImage: "tray")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ItinerarySection: View {
    let trip: Trip
    let items: [ItineraryItem]
    let openDirections: (ItineraryItem, Trip) -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Itinerary")
                    .font(.headline)
                    .fontDesign(.rounded)

                if items.isEmpty {
                    Label("No itinerary items yet", systemImage: "list.bullet.clipboard")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(items) { item in
                            ItineraryItemRow(
                                trip: trip,
                                item: item,
                                openDirections: openDirections
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct ItineraryItemRow: View {
    let trip: Trip
    let item: ItineraryItem
    let openDirections: (ItineraryItem, Trip) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.category.systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.teal, in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Text(item.dayDisplayString)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(item.category.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.tint(.teal.opacity(0.14)), in: .capsule)

                    if item.hasCoordinate {
                        Label("Exact", systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Search", systemImage: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if item.notesOrAddress.isEmpty == false {
                    Text(item.notesOrAddress)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill") {
                    openDirections(item, trip)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(item.directionsAccessibilityLabel)
                .accessibilityHint("Opens driving directions in Apple Maps")
            }
        }
        .padding(12)
        .glassEffect(.regular.tint(.teal.opacity(0.08)), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }
}
