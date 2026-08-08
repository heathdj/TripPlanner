import CoreLocation
import SwiftData
import SwiftUI
import UIKit

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var reviewedPlans: [ReviewedTripPlan]
    @AppStorage(TravelPreferencesStorage.Key.selectedInterestNames) private var selectedInterestNamesData = TravelPreferencesStorage.defaultSelectedInterestsData
    @AppStorage(TravelPreferencesStorage.Key.customInterestNames) private var customInterestNamesData = TravelPreferencesStorage.defaultCustomInterestsData
    @State private var generatedDraft: TripPlanDraft?
    @State private var editablePlan = EditableTripPlan()
    @State private var isShowingReviewSheet = false
    @State private var generationMessage: String?
    @State private var isGeneratingDraft = false
    @State private var didStartInitialGeneration = false
    @State private var hasSavedReviewedPlan = false

    let trip: Trip
    var distanceSummary: String?
    var userLocation: CLLocation?
    var nearYouDistanceKilometers = TravelSettings.defaultNearYouDistanceKilometers
    var startsGeneratingDraftOnAppear = false
    var tripPlanGenerator: any TripPlanGenerating = FoundationModelsTripPlanGenerator()
    var generatedTripSaved: (Trip) -> Void = { _ in }

    private var savedPlan: ReviewedTripPlan? {
        reviewedPlans
            .filter { $0.tripID == trip.id }
            .sorted { $0.reviewedAt > $1.reviewedAt }
            .first
    }

    private var selectedInterests: [String] {
        TravelPreferencesStorage.visibleSelectedInterests(
            selected: TravelPreferencesStorage.decodeInterests(from: selectedInterestNamesData),
            custom: TravelPreferencesStorage.decodeInterests(from: customInterestNamesData)
        )
    }

    private var isGeneratedTripFlow: Bool {
        startsGeneratingDraftOnAppear
    }

    private var canSaveGeneratedTrip: Bool {
        hasSavedReviewedPlan || savedPlan != nil
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
                        GeneratedPlanSection(
                            status: tripPlanGenerator.status,
                            selectedInterests: selectedInterests,
                            draft: generatedDraft,
                            message: generationMessage,
                            isGenerating: isGeneratingDraft,
                            reviewDraft: reviewDraft,
                            generate: generateDraft
                        )
                        ItinerarySection(
                            trip: trip,
                            items: trip.itineraryItems,
                            refreshItem: refreshPlaceDetails
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
                    if isGeneratedTripFlow {
                        Button("Cancel") {
                            cancelGeneratedTrip()
                        }
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }

                if isGeneratedTripFlow {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveGeneratedTrip()
                        }
                        .disabled(canSaveGeneratedTrip == false)
                    }
                }
            }
            .interactiveDismissDisabled(isGeneratedTripFlow && canSaveGeneratedTrip == false)
            .task {
                guard startsGeneratingDraftOnAppear,
                      didStartInitialGeneration == false
                else {
                    return
                }

                didStartInitialGeneration = true
                generateDraft()
            }
            .sheet(isPresented: $isShowingReviewSheet) {
                GeneratedPlanReviewSheet(
                    trip: trip,
                    plan: $editablePlan,
                    userLocation: userLocation,
                    nearYouDistanceKilometers: nearYouDistanceKilometers,
                    savePlan: saveReviewedPlan
                )
            }
        }
    }

    private func generateDraft() {
        guard isGeneratingDraft == false else { return }

        isGeneratingDraft = true
        generationMessage = nil

        let input = TripPlanGenerationInput(
            trip: trip,
            selectedInterests: selectedInterests
        )

        Task {
            do {
                generatedDraft = try await tripPlanGenerator.generateDraft(for: input)
                if let generatedDraft {
                    editablePlan = EditableTripPlan(draft: generatedDraft)
                    isShowingReviewSheet = true
                }
            } catch let error as TripPlanGenerationError {
                generatedDraft = nil
                generationMessage = error.localizedDescription
            } catch {
                generatedDraft = nil
                generationMessage = "Trip generation failed. Try again in a moment."
            }

            isGeneratingDraft = false
        }
    }

    private func reviewDraft() {
        if let generatedDraft {
            editablePlan = EditableTripPlan(draft: generatedDraft)
        }

        isShowingReviewSheet = true
    }

    private func saveReviewedPlan(_ plan: EditableTripPlan) throws {
        _ = try ReviewedTripPlanStore.saveReviewedPlan(
            title: plan.title,
            overview: plan.overview,
            items: plan.itineraryItems,
            for: trip,
            in: modelContext
        )
        trip.status = .open
        trip.updatedAt = .now
        generatedDraft = nil
        hasSavedReviewedPlan = true
    }

    private func saveGeneratedTrip() {
        guard canSaveGeneratedTrip else { return }

        trip.status = .open
        trip.updatedAt = .now

        do {
            try modelContext.save()
            generatedTripSaved(trip)
            dismiss()
        } catch {
            generationMessage = "Trip Planner could not save this trip. Try saving again."
        }
    }

    private func cancelGeneratedTrip() {
        discardGeneratedTrip()

        dismiss()
    }

    private func discardGeneratedTrip() {
        let tripID = trip.id
        let tripDescriptor = FetchDescriptor<Trip>(
            predicate: #Predicate { savedTrip in
                savedTrip.id == tripID
            }
        )
        let planDescriptor = FetchDescriptor<ReviewedTripPlan>(
            predicate: #Predicate { plan in
                plan.tripID == tripID
            }
        )

        if let savedTrips = try? modelContext.fetch(tripDescriptor) {
            savedTrips.forEach { modelContext.delete($0) }
        }

        if let savedPlans = try? modelContext.fetch(planDescriptor) {
            savedPlans.forEach { modelContext.delete($0) }
        }

        try? modelContext.save()
    }

    private func refreshPlaceDetails(for item: ItineraryItem) {
        Task {
            guard let refreshedItem = try? await PlaceMetadataRefreshService.refreshedItem(item, in: trip),
                  let itemIndex = trip.itineraryItems.firstIndex(where: { $0.id == item.id })
            else {
                return
            }

            trip.itineraryItems[itemIndex] = refreshedItem
            trip.updatedAt = .now
            try? modelContext.save()
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

private struct GeneratedPlanSection: View {
    let status: TripPlanGenerationStatus
    let selectedInterests: [String]
    let draft: TripPlanDraft?
    let message: String?
    let isGenerating: Bool
    let reviewDraft: () -> Void
    let generate: () -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.teal, in: .circle)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Generated Draft")
                            .font(.headline)
                            .fontDesign(.rounded)

                        Text(status.message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
                }

                if selectedInterests.isEmpty == false {
                    InterestSummary(interests: selectedInterests)
                }

                if let message {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let draft {
                    GeneratedDraftPreview(draft: draft, reviewDraft: reviewDraft)
                }

                Button {
                    generate()
                } label: {
                    if isGenerating {
                        Label("Generating", systemImage: "hourglass")
                    } else {
                        Label(draft == nil ? "Generate Draft" : "Regenerate Draft", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isGenerating || status.isAvailable == false)
                .accessibilityHint("Creates an on-device draft without saving it to this trip")
            }
        }
    }
}

private struct InterestSummary: View {
    let interests: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Using Interests")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(interests, id: \.self) { interest in
                    Text(interest)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.tint(.teal.opacity(0.14)), in: .capsule)
                }
            }
        }
    }
}

private struct GeneratedDraftPreview: View {
    let draft: TripPlanDraft
    let reviewDraft: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(draft.title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(draft.overview)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label("Draft only. Review and save to update this trip.", systemImage: "pencil.and.list.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(draft.items) { item in
                    GeneratedDraftItemRow(item: item)
                }
            }

            Button("Review Draft", systemImage: "pencil.and.list.clipboard") {
                reviewDraft()
            }
            .buttonStyle(.glass)
            .accessibilityHint("Opens the generated plan for editing before saving")
        }
        .padding(12)
        .glassEffect(.regular.tint(.teal.opacity(0.08)), in: .rect(cornerRadius: 16))
    }
}

private struct GeneratedDraftItemRow: View {
    let item: ItineraryItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.category.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.teal)
                .frame(width: 28, height: 28)
                .glassEffect(.regular.tint(.teal.opacity(0.14)), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Text(item.dayDisplayString)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(item.category.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)

                if item.notesOrAddress.isEmpty == false {
                    Text(item.notesOrAddress)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct EditableTripPlan {
    var title: String
    var overview: String
    var items: [EditableItineraryItem]

    nonisolated init(
        title: String = "",
        overview: String = "",
        items: [EditableItineraryItem] = []
    ) {
        self.title = title
        self.overview = overview
        self.items = items
    }

    nonisolated init(draft: TripPlanDraft) {
        self.init(
            title: draft.title,
            overview: draft.overview,
            items: draft.items.map { EditableItineraryItem(item: $0) }
        )
    }

    var hasValidTitle: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var hasNamedItem: Bool {
        items.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    }

    var canSave: Bool {
        hasValidTitle && hasNamedItem
    }

    var itineraryItems: [ItineraryItem] {
        items.map(\.itineraryItem)
    }
}

private struct EditableItineraryItem: Identifiable {
    var id: UUID
    var name: String
    var notesOrAddress: String
    var category: ItineraryItemCategory
    var dayNumber: Int
    var latitude: Double?
    var longitude: Double?
    var mapItemIdentifier: String?
    var phoneNumber: String?
    var pointOfInterestCategoryName: String?
    var placeAddress: PlaceDetailValue?
    var placePhoneNumber: PlaceDetailValue?
    var placeWebsite: PlaceDetailValue?
    var placeCategory: PlaceDetailValue?
    var placeHours: PlaceDetailValue?
    var placeCost: PlaceDetailValue?
    var placeTimeZoneIdentifier: String?
    var placeAttribution: PlaceDetailValue?

    nonisolated init(
        id: UUID = UUID(),
        name: String = "",
        notesOrAddress: String = "",
        category: ItineraryItemCategory = .activity,
        dayNumber: Int = 1,
        latitude: Double? = nil,
        longitude: Double? = nil,
        mapItemIdentifier: String? = nil,
        phoneNumber: String? = nil,
        pointOfInterestCategoryName: String? = nil,
        placeAddress: PlaceDetailValue? = nil,
        placePhoneNumber: PlaceDetailValue? = nil,
        placeWebsite: PlaceDetailValue? = nil,
        placeCategory: PlaceDetailValue? = nil,
        placeHours: PlaceDetailValue? = nil,
        placeCost: PlaceDetailValue? = nil,
        placeTimeZoneIdentifier: String? = nil,
        placeAttribution: PlaceDetailValue? = nil
    ) {
        self.id = id
        self.name = name
        self.notesOrAddress = notesOrAddress
        self.category = category
        self.dayNumber = max(1, dayNumber)
        self.latitude = latitude
        self.longitude = longitude
        self.mapItemIdentifier = mapItemIdentifier
        self.phoneNumber = phoneNumber
        self.pointOfInterestCategoryName = pointOfInterestCategoryName
        self.placeAddress = placeAddress
        self.placePhoneNumber = placePhoneNumber
        self.placeWebsite = placeWebsite
        self.placeCategory = placeCategory
        self.placeHours = placeHours
        self.placeCost = placeCost
        self.placeTimeZoneIdentifier = placeTimeZoneIdentifier
        self.placeAttribution = placeAttribution
    }

    nonisolated init(item: ItineraryItem) {
        self.init(
            id: item.id,
            name: item.name,
            notesOrAddress: item.notesOrAddress,
            category: item.category,
            dayNumber: item.dayNumber,
            latitude: item.latitude,
            longitude: item.longitude,
            mapItemIdentifier: item.mapItemIdentifier,
            phoneNumber: item.phoneNumber,
            pointOfInterestCategoryName: item.pointOfInterestCategoryName,
            placeAddress: item.placeAddress,
            placePhoneNumber: item.placePhoneNumber,
            placeWebsite: item.placeWebsite,
            placeCategory: item.placeCategory,
            placeHours: item.placeHours,
            placeCost: item.placeCost,
            placeTimeZoneIdentifier: item.placeTimeZoneIdentifier,
            placeAttribution: item.placeAttribution
        )
    }

    var itineraryItem: ItineraryItem {
        ItineraryItem(
            id: id,
            name: name,
            notesOrAddress: notesOrAddress,
            category: category,
            dayNumber: dayNumber,
            latitude: latitude,
            longitude: longitude,
            mapItemIdentifier: mapItemIdentifier,
            phoneNumber: phoneNumber,
            pointOfInterestCategoryName: pointOfInterestCategoryName,
            placeAddress: normalizedDetail(placeAddress, fallback: notesOrAddress, source: .user),
            placePhoneNumber: normalizedDetail(placePhoneNumber, fallback: phoneNumber, source: .user),
            placeWebsite: normalizedDetail(placeWebsite, fallback: nil, source: .user),
            placeCategory: normalizedDetail(placeCategory, fallback: pointOfInterestCategoryName, source: .user),
            placeHours: normalizedDetail(placeHours, fallback: nil, source: .user),
            placeCost: normalizedDetail(placeCost, fallback: nil, source: .user),
            placeTimeZoneIdentifier: placeTimeZoneIdentifier,
            placeAttribution: placeAttribution
        )
    }

    private func normalizedDetail(
        _ detail: PlaceDetailValue?,
        fallback: String?,
        source: PlaceDetailSource
    ) -> PlaceDetailValue? {
        if let detail,
           detail.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return detail
        }

        guard let fallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines),
              fallback.isEmpty == false
        else {
            return nil
        }

        return PlaceDetailValue(value: fallback, source: source)
    }

    mutating func setPlaceDetail(
        _ keyPath: WritableKeyPath<EditableItineraryItem, PlaceDetailValue?>,
        value: String,
        source: PlaceDetailSource
    ) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self[keyPath: keyPath] = normalized.isEmpty ? nil : PlaceDetailValue(value: normalized, source: source)
    }
}

private struct GeneratedPlanReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    @Binding var plan: EditableTripPlan
    let userLocation: CLLocation?
    let nearYouDistanceKilometers: Double
    let savePlan: (EditableTripPlan) throws -> Void

    @State private var saveErrorMessage: String?
    @State private var pendingItem: EditableItineraryItem?

    private var isShowingSaveError: Binding<Bool> {
        Binding {
            saveErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                saveErrorMessage = nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    TextField("Title", text: $plan.title)
                        .textInputAutocapitalization(.words)

                    TextField("Overview", text: $plan.overview, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }

                Section {
                    ForEach($plan.items) { $item in
                        EditableItineraryItemSection(
                            trip: trip,
                            item: $item,
                            userLocation: userLocation,
                            nearYouDistanceKilometers: nearYouDistanceKilometers,
                            deleteItem: {
                                deleteItem(id: item.id)
                            }
                        )
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                deleteItem(id: item.id)
                            }
                            .tint(.red)
                        }
                    }

                    if let pendingItemBinding {
                        EditableItineraryItemSection(
                            trip: trip,
                            item: pendingItemBinding,
                            userLocation: userLocation,
                            nearYouDistanceKilometers: nearYouDistanceKilometers,
                            confirmItem: confirmPendingItem,
                            deleteItem: cancelPendingItem
                        )
                        .swipeActions(edge: .trailing) {
                            Button("Discard", systemImage: "trash", role: .destructive) {
                                cancelPendingItem()
                            }
                            .tint(.red)
                        }
                    }

                    Button("Add Item", systemImage: "plus") {
                        addItem()
                    }
                    .disabled(pendingItem != nil)
                } header: {
                    Text("Items")
                } footer: {
                    Text("Save is available when the plan has a title and at least one named item.")
                }
            }
            .navigationTitle("Review Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(plan.canSave == false)
                }
            }
            .alert("Plan Not Saved", isPresented: isShowingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage ?? "Review the plan and try again.")
            }
        }
    }

    private var pendingItemBinding: Binding<EditableItineraryItem>? {
        guard pendingItem != nil else { return nil }

        return Binding {
            pendingItem ?? EditableItineraryItem()
        } set: { newValue in
            pendingItem = newValue
        }
    }

    private func addItem() {
        let nextDay = min(max(1, plan.items.last?.dayNumber ?? pendingItem?.dayNumber ?? 1), trip.durationDays)
        pendingItem =
            EditableItineraryItem(
                name: "",
                notesOrAddress: "",
                category: .activity,
                dayNumber: nextDay
            )
    }

    private func deleteItem(id: UUID) {
        plan.items.removeAll { $0.id == id }
    }

    private func confirmPendingItem() {
        guard let pendingItem,
              pendingItem.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return
        }

        plan.items.append(pendingItem)
        self.pendingItem = nil
    }

    private func cancelPendingItem() {
        pendingItem = nil
    }

    private func save() {
        do {
            try savePlan(plan)
            dismiss()
        } catch let error as ReviewedTripPlanStore.ValidationError {
            saveErrorMessage = error.localizedDescription
        } catch {
            saveErrorMessage = "Trip Planner could not save this reviewed plan. Try again."
        }
    }
}

private struct EditableItineraryItemSection: View {
    let trip: Trip
    let userLocation: CLLocation?
    let nearYouDistanceKilometers: Double
    @Binding var item: EditableItineraryItem
    var confirmItem: (() -> Void)?
    let deleteItem: () -> Void

    @State private var placeQuery = ""
    @State private var placeSearch: ActivityPlaceSearchService

    init(
        trip: Trip,
        item: Binding<EditableItineraryItem>,
        userLocation: CLLocation?,
        nearYouDistanceKilometers: Double,
        confirmItem: (() -> Void)? = nil,
        deleteItem: @escaping () -> Void
    ) {
        self.trip = trip
        self.userLocation = userLocation
        self.nearYouDistanceKilometers = nearYouDistanceKilometers
        _item = item
        self.confirmItem = confirmItem
        self.deleteItem = deleteItem

        let destinationCoordinate: CLLocationCoordinate2D?
        if let latitude = trip.latitude,
           let longitude = trip.longitude {
            destinationCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            destinationCoordinate = nil
        }

        _placeSearch = State(
            initialValue: ActivityPlaceSearchService(
                destination: trip.location,
                destinationCoordinate: destinationCoordinate,
                userLocation: userLocation,
                nearYouDistanceKilometers: nearYouDistanceKilometers
            )
        )
    }

    private var canConfirm: Bool {
        item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Item" : item.name)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if let confirmItem {
                    Button("Confirm", systemImage: "checkmark.circle.fill") {
                        confirmItem()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.green)
                    .disabled(canConfirm == false)
                    .accessibilityLabel("Confirm item")
                    .accessibilityHint("Adds this item to the reviewed plan")
                }

                Button("Delete", systemImage: "trash", role: .destructive) {
                    deleteItem()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete \(item.name.isEmpty ? "item" : item.name)")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Find a place near \(trip.location)", text: $placeQuery)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onChange(of: placeQuery) {
                            placeSearch.updateQuery(placeQuery)
                        }

                    Button("Search", systemImage: "magnifyingglass") {
                        searchEnteredPlace()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(placeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Search places")
                }

                if placeSearch.suggestions.isEmpty == false {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(placeSearch.suggestions) { suggestion in
                            Button {
                                selectPlace(suggestion)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    if suggestion.subtitle.isEmpty == false {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(suggestion.displayText)
                            .accessibilityHint("Fills this itinerary item with this place")
                        }
                    }
                }

                if placeSearch.isResolvingPlace {
                    Label("Finding place details", systemImage: "location.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let errorMessage = placeSearch.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Name", text: $item.name)
                .textInputAutocapitalization(.words)

            TextField("Notes or address", text: $item.notesOrAddress, axis: .vertical)
                .lineLimit(2...4)
                .textInputAutocapitalization(.sentences)

            TextField("Verified address", text: detailBinding(\.placeAddress))
                .textInputAutocapitalization(.words)

            TextField("Website", text: detailBinding(\.placeWebsite))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)

            TextField("Phone", text: detailBinding(\.placePhoneNumber))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.phonePad)

            TextField("Business category", text: detailBinding(\.placeCategory))
                .textInputAutocapitalization(.words)

            TextField("Hours", text: detailBinding(\.placeHours), axis: .vertical)
                .lineLimit(2...4)
                .textInputAutocapitalization(.sentences)

            TextField("Cost guidance", text: detailBinding(\.placeCost))
                .textInputAutocapitalization(.sentences)

            Picker("Category", selection: $item.category) {
                ForEach(ItineraryItemCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.systemImage)
                        .tag(category)
                }
            }

            Stepper(value: dayBinding, in: 1...max(1, trip.durationDays), step: 1) {
                LabeledContent("Day", value: "Day \(item.dayNumber)")
            }

            if item.latitude != nil || item.longitude != nil {
                Label("Location coordinates will be kept for Maps directions.", systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Directions will search this item with the trip destination.", systemImage: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func searchEnteredPlace() {
        Task {
            guard let suggestion = await placeSearch.searchEnteredPlace(placeQuery) else { return }
            applyPlaceSuggestion(suggestion)
        }
    }

    private func selectPlace(_ suggestion: ActivityPlaceSuggestion) {
        Task {
            let resolvedSuggestion = await placeSearch.resolvedSuggestion(for: suggestion)
            applyPlaceSuggestion(resolvedSuggestion)
        }
    }

    private func applyPlaceSuggestion(_ suggestion: ActivityPlaceSuggestion) {
        item.name = suggestion.title

        if suggestion.address.isEmpty == false {
            item.notesOrAddress = suggestion.address
        } else if suggestion.subtitle.isEmpty == false {
            item.notesOrAddress = suggestion.subtitle
        }

        item.latitude = suggestion.latitude
        item.longitude = suggestion.longitude
        item.mapItemIdentifier = suggestion.mapItemIdentifier
        item.phoneNumber = suggestion.phoneNumber
        item.pointOfInterestCategoryName = suggestion.pointOfInterestCategoryName
        item.placeTimeZoneIdentifier = suggestion.timeZoneIdentifier
        item.placeAttribution = PlaceDetailValue(value: "Apple Maps", source: .provider)
        item.setPlaceDetail(\.placeAddress, value: suggestion.address.isEmpty ? suggestion.subtitle : suggestion.address, source: .provider)
        item.setPlaceDetail(\.placePhoneNumber, value: suggestion.phoneNumber ?? "", source: .provider)
        item.setPlaceDetail(\.placeWebsite, value: suggestion.website ?? "", source: .provider)
        item.setPlaceDetail(\.placeCategory, value: suggestion.pointOfInterestCategoryName ?? "", source: .provider)
        item.category = category(for: suggestion.pointOfInterestCategoryName)
        placeQuery = suggestion.displayText
        placeSearch.clearSuggestions()
    }

    private func category(for pointOfInterestCategoryName: String?) -> ItineraryItemCategory {
        let normalized = pointOfInterestCategoryName?.lowercased() ?? ""

        if normalized.contains("restaurant") || normalized.contains("cafe") || normalized.contains("food") || normalized.contains("brewery") || normalized.contains("winery") {
            return .food
        }

        if normalized.contains("hotel") || normalized.contains("lodging") {
            return .stay
        }

        if normalized.contains("airport") || normalized.contains("parking") || normalized.contains("publictransport") {
            return .transit
        }

        return .activity
    }

    private func detailBinding(_ keyPath: WritableKeyPath<EditableItineraryItem, PlaceDetailValue?>) -> Binding<String> {
        Binding {
            item[keyPath: keyPath]?.value ?? ""
        } set: { newValue in
            item.setPlaceDetail(keyPath, value: newValue, source: .user)
        }
    }

    private var dayBinding: Binding<Int> {
        Binding {
            min(max(1, item.dayNumber), max(1, trip.durationDays))
        } set: { newValue in
            item.dayNumber = min(max(1, newValue), max(1, trip.durationDays))
        }
    }
}

private struct ItinerarySection: View {
    let trip: Trip
    let items: [ItineraryItem]
    let refreshItem: (ItineraryItem) -> Void

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
                                refreshItem: refreshItem
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
    let refreshItem: (ItineraryItem) -> Void

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

                if item.hasPlaceDetails {
                    PlaceDetailsGrid(item: item)
                }

                HStack(spacing: 8) {
                    Button("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill") {
                        AppleMapsDirectionsService.openDirections(for: item, in: trip)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(item.directionsAccessibilityLabel)
                    .accessibilityHint("Opens driving directions in Apple Maps")

                    if let websiteURL = validatedWebsiteURL {
                        Button("Website", systemImage: "safari.fill") {
                            UIApplication.shared.open(websiteURL)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Open website for \(item.name)")
                    }

                    if let phoneURL = validatedPhoneURL {
                        Button("Call", systemImage: "phone.fill") {
                            UIApplication.shared.open(phoneURL)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Call \(item.name)")
                    }

                    Button("Refresh", systemImage: "arrow.clockwise") {
                        refreshItem(item)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Refresh place details for \(item.name)")
                }
            }
        }
        .padding(12)
        .glassEffect(.regular.tint(.teal.opacity(0.08)), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private var validatedWebsiteURL: URL? {
        let rawValue = item.displayWebsite.trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawValue.isEmpty == false,
              var components = URLComponents(string: rawValue)
        else {
            return nil
        }

        if components.scheme == nil {
            components.scheme = "https"
        }

        guard let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false
        else {
            return nil
        }

        return components.url
    }

    private var validatedPhoneURL: URL? {
        let digits = item.displayPhoneNumber.filter(\.isNumber)
        guard digits.count >= 7 else { return nil }
        return URL(string: "tel://\(digits)")
    }
}

private struct PlaceDetailsGrid: View {
    let item: ItineraryItem

    private var details: [(title: String, value: String, source: PlaceDetailSource?)] {
        [
            ("Address", item.displayAddress, item.placeAddress?.source),
            ("Phone", item.displayPhoneNumber, item.placePhoneNumber?.source),
            ("Website", item.displayWebsite, item.placeWebsite?.source),
            ("Category", item.displayPlaceCategory, item.placeCategory?.source),
            ("Hours", item.displayHoursWithTimeZone, item.placeHours?.source),
            ("Cost", item.displayCost, item.placeCost?.source),
            ("Attribution", item.placeAttribution?.value ?? "", item.placeAttribution?.source)
        ]
        .filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(details, id: \.title) { detail in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(detail.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if let source = detail.source {
                            Text(source == .provider ? "Provider" : "Manual")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(source == .provider ? .teal : .orange)
                        }
                    }

                    Text(detail.value)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 4)
    }
}

private extension ItineraryItem {
    var displayHoursWithTimeZone: String {
        guard displayHours.isEmpty == false else { return "" }

        if let placeTimeZone {
            return "\(displayHours) (\(placeTimeZone.identifier))"
        }

        return displayHours
    }
}
