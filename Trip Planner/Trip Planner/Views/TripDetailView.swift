import SwiftData
import SwiftUI

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
    var startsGeneratingDraftOnAppear = false
    var openDirections: (ItineraryItem, Trip) -> Void = AppleMapsDirectionsService.openDirections
    var tripPlanGenerator: any TripPlanGenerating = FoundationModelsTripPlanGenerator()

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
                            dismiss()
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
        generatedDraft = nil
        hasSavedReviewedPlan = true
    }

    private func cancelGeneratedTrip() {
        if canSaveGeneratedTrip == false {
            modelContext.delete(trip)
            try? modelContext.save()
        }

        dismiss()
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

    init(
        title: String = "",
        overview: String = "",
        items: [EditableItineraryItem] = []
    ) {
        self.title = title
        self.overview = overview
        self.items = items
    }

    init(draft: TripPlanDraft) {
        self.init(
            title: draft.title,
            overview: draft.overview,
            items: draft.items.map(EditableItineraryItem.init)
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

    init(
        id: UUID = UUID(),
        name: String = "",
        notesOrAddress: String = "",
        category: ItineraryItemCategory = .activity,
        dayNumber: Int = 1,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.notesOrAddress = notesOrAddress
        self.category = category
        self.dayNumber = max(1, dayNumber)
        self.latitude = latitude
        self.longitude = longitude
    }

    init(item: ItineraryItem) {
        self.init(
            id: item.id,
            name: item.name,
            notesOrAddress: item.notesOrAddress,
            category: item.category,
            dayNumber: item.dayNumber,
            latitude: item.latitude,
            longitude: item.longitude
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
            longitude: longitude
        )
    }
}

private struct GeneratedPlanReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    @Binding var plan: EditableTripPlan
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
    @Binding var item: EditableItineraryItem
    var confirmItem: (() -> Void)?
    let deleteItem: () -> Void

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

            TextField("Name", text: $item.name)
                .textInputAutocapitalization(.words)

            TextField("Notes or address", text: $item.notesOrAddress, axis: .vertical)
                .lineLimit(2...4)
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
