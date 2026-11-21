import SwiftUI

struct CustomWorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlusPurchaseStore.self) private var plus
    let repository: TrainingRepository
    @State private var draft: WorkoutDefinition
    @State private var editingStep: BuilderStepDestination?
    @State private var validation: String?

    // An intentional editing copy: cancel never changes the saved template.
    init(repository: TrainingRepository, workout: WorkoutDefinition? = nil) {
        self.repository = repository
        var initial = workout ?? WorkoutFactory.make(.custom, preferences: repository.preferences)
        if workout == nil {
            initial.id = "custom-" + UUID().uuidString
            initial.title = "My hybrid session"
            initial.rounds = 2
        }
        _draft = State(initialValue: initial)
    }
    var body: some View {
        NavigationStack {
            Form {
                introduction
                details
                Section("Main rounds") {
                    Stepper("\(draft.rounds) \(draft.rounds == 1 ? "round" : "rounds")", value: $draft.rounds, in: 1...12)
                }.listRowBackground(TrainingTheme.surface)
                stepSection("Warm-up", phase: .warmup, steps: draft.warmup)
                stepSection("Main work · repeated each round", phase: .work, steps: draft.main)
                stepSection("Cool down", phase: .cooldown, steps: draft.cooldown)
                Section {
                    Text("Use the reorder control to arrange steps. Distance and repetitions are completed manually; timed steps advance automatically.")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                    SafetyNote()
                }.listRowBackground(TrainingTheme.surface)
                if let message = validation ?? repository.storageError { Section { Text(message).foregroundStyle(TrainingTheme.mint) } }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Workout builder").navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(item: $editingStep) { stepEditor($0) }
            .safeAreaInset(edge: .bottom) { saveBar }
            .trainingScreen()
        }
    }
    private var introduction: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                PlusBadge()
                Text("A session, shaped by you.").font(.title2.bold())
                HStack(spacing: 18) {
                    Label("~\(draft.estimatedMinutes) min", systemImage: "clock")
                    Label("\(draft.expandedSteps.count) steps", systemImage: "list.bullet")
                }.font(.subheadline).foregroundStyle(TrainingTheme.mint)
                Text("Start with these editable steps, or make it entirely your own.").font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }.padding(.vertical, 6)
        }.listRowBackground(TrainingTheme.surface)
    }
    private var details: some View {
        Section("Session details") {
            TextField("Workout name", text: $draft.title).accessibilityLabel("Workout name")
            TextField("What’s the purpose?", text: $draft.purpose, axis: .vertical).lineLimit(2...4)
                .accessibilityLabel("Workout purpose")
            Picker("Experience level", selection: $draft.level) {
                ForEach(AthleteLevel.allCases) { Text($0.title).tag($0) }
            }
        }.listRowBackground(TrainingTheme.surface)
    }
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .primaryAction) { EditButton() }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
        }
    }
    private func stepSection(_ title: String, phase: TrainingPhase, steps: [WorkoutStep]) -> some View {
        Section {
            ForEach(steps) { step in
                Button { editingStep = BuilderStepDestination(step: step, phase: phase, isNew: false) } label: {
                    HStack(spacing: 12) {
                        ExerciseDemoThumbnail(exercise: step.exercise)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(step.title).font(.body.weight(.medium)).foregroundStyle(TrainingTheme.primary)
                            Text(step.targetText(units: repository.preferences.units)).font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "pencil").foregroundStyle(TrainingTheme.mint)
                    }.padding(.vertical, 6)
                }.buttonStyle(.plain)
            }.onMove { source, target in move(source, to: target, phase: phase) }
            Button {
                if steps.count >= 40 { validation = "Keep each section to 40 steps or fewer."; return }
                editingStep = BuilderStepDestination(step: ExerciseCatalog.step(phase == .work ? "squat" : "walk"), phase: phase, isNew: true)
            } label: { Label("Add a movement or rest", systemImage: "plus.circle").frame(minHeight: 44) }
        } header: { Text(title) }
            .listRowBackground(TrainingTheme.surface)
    }
    private func stepEditor(_ destination: BuilderStepDestination) -> some View {
        WorkoutStepEditorView(step: destination.step, units: repository.preferences.units,
                              canDelete: !destination.isNew && (destination.phase != .work || draft.main.count > 1),
                              save: { apply($0, destination: destination) }, delete: { remove(destination) })
    }
    private var saveBar: some View {
        Button("Save & use this workout", action: save)
            .buttonStyle(TrainingButtonStyle()).padding(.horizontal, 20).padding(.vertical, 12)
            .background(TrainingTheme.background)
    }
    private func save() {
        guard plus.isPlus else { validation = "An active Hybrid Plus subscription is needed to save a custom template."; return }
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 80 else { validation = "Give your workout a name of 1–80 characters."; return }
        guard draft.purpose.count <= 500 else { validation = "Keep the purpose under 500 characters."; return }
        guard !draft.main.isEmpty, draft.expandedSteps.count <= 500 else { validation = "Add main work and keep the session to 500 expanded steps or fewer."; return }
        draft.title = title
        if draft.purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { draft.purpose = WorkoutFamily.custom.purpose }
        draft.timeBudget = draft.estimatedMinutes
        if repository.storeCustomWorkout(draft) { dismiss() }
    }
    private func apply(_ step: WorkoutStep, destination: BuilderStepDestination) {
        var steps = steps(for: destination.phase)
        if destination.isNew { steps.append(step) }
        else if let index = steps.firstIndex(where: { $0.id == step.id }) { steps[index] = step }
        setSteps(steps, phase: destination.phase)
        validation = nil
    }
    private func remove(_ destination: BuilderStepDestination) {
        var items = steps(for: destination.phase)
        if destination.phase == .work && items.count <= 1 { return }
        items.removeAll { $0.id == destination.step.id }
        setSteps(items, phase: destination.phase)
    }
    private func move(_ source: IndexSet, to target: Int, phase: TrainingPhase) {
        var items = steps(for: phase)
        items.move(fromOffsets: source, toOffset: target)
        setSteps(items, phase: phase)
    }
    private func steps(for phase: TrainingPhase) -> [WorkoutStep] {
        switch phase {
        case .warmup: draft.warmup
        case .cooldown: draft.cooldown
        default: draft.main
        }
    }
    private func setSteps(_ items: [WorkoutStep], phase: TrainingPhase) {
        switch phase {
        case .warmup: draft.warmup = items
        case .cooldown: draft.cooldown = items
        default: draft.main = items
        }
    }
}

private struct BuilderStepDestination: Identifiable {
    let step: WorkoutStep
    let phase: TrainingPhase
    let isNew: Bool
    var id: String { step.id }
}
