import SwiftUI

struct DashboardView: View {
    let store: TripStore

    private let columns = [
        GridItem(.adaptive(minimum: 280), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientMapBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HeroPanel(store: store)

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                            ForEach(store.trips) { trip in
                                TripSummaryCard(trip: trip)
                            }
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
                    Button("Add Trip", systemImage: "plus") { }
                        .buttonStyle(.glassProminent)
                        .accessibilityHint("Creates a new trip")
                }
            }
        }
    }
}

private struct HeroPanel: View {
    let store: TripStore

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            GlassPanel(cornerRadius: 28) {
                VStack(alignment: .leading, spacing: 20) {
                    Label("First Release Foundation", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("Plan the next good day away.")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .fixedSize(horizontal: false, vertical: true)

                    if let nextTrip = store.nextTrip {
                        Text(nextTrip.highlight)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 12) {
                        StatPill(
                            title: "Active Trips",
                            value: "\(store.activeTrips.count)",
                            systemImage: "suitcase.rolling.fill"
                        )

                        StatPill(
                            title: "Planned Items",
                            value: "\(store.plannedItemTotal)",
                            systemImage: "list.bullet.clipboard.fill"
                        )
                    }
                }
            }
        }
    }
}

private struct TripSummaryCard: View {
    let trip: TripSummary

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

                HStack {
                    Label(trip.dateRange, systemImage: "calendar")
                    Spacer(minLength: 12)
                    Text(trip.status.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.tint(.orange.opacity(0.18)), in: .capsule)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
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

private struct MapGridPattern: Shape {
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
