import SwiftUI

struct AdjustWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    let repository: TrainingRepository
    @State private var draft: WorkoutDefinition
    @State private var preferences: AthletePreferences
    @State private var editingStep: StepEditorDestination?
    @State private var confirmReset = false

    // This screen owns a one-time editing copy; Cancel leaves the saved workout untouched.
    init(repository: TrainingRepository, workout: WorkoutDefinition) {
        self.repository = repository
        _draft = State(initialValue: workout)
        var preferences = repository.preferences
        preferences.level = workout.level
        preferences.timeBudget = workout.timeBudget
        _preferences = State(initialValue: preferences)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introduction
                    levelSection
                    timeSection
                    equipmentSection
                    stepsSection
                    resetSection
                    if let error = repository.storageError { Text(error).font(.body) }
                    SafetyNote()
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle("Make it yours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(item: $editingStep) { destination in
                WorkoutStepEditorView(step: destination.step, units: preferences.units,
                                      canDelete: canDelete(destination),
                                      save: { apply($0, destination: destination) },
                                      delete: { remove(destination) })
            }
            .confirmationDialog("Reset this workout?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset to starter steps") { rebuild() }
            } message: { Text("Your step edits will be replaced with a starter session using the choices above. Saved results won’t change.") }
            .onChange(of: preferences.level) { _, _ in rebuild() }
            .onChange(of: preferences.timeBudget) { _, _ in rebuild() }
            .onChange(of: preferences.equipment) { _, _ in rebuild() }
            .trainingScreen()
        }
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: draft.family.category, color: TrainingTheme.mint)
            Text(draft.title).font(.title2.weight(.bold))
            Text("Your session, your pace. Adjust the basics, then fine-tune any movement.")
                .font(.body).foregroundStyle(TrainingTheme.secondary)
            if repository.active != nil {
                Label("Changes apply to your next workout, not the session already in progress.", systemImage: "info.circle")
                    .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }
        }
    }
    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Your experience")
            ForEach(AthleteLevel.allCases) { level in
                ChoiceRow(title: level.title, detail: preferences.level == level ? level.detail : nil,
                          selected: preferences.level == level) { preferences.level = level }
            }
        }
    }
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Available time", subtitle: "We’ll suggest rounds to fit. Actual time depends on your pace.")
            Picker("Available minutes", selection: $preferences.timeBudget) {
                Text("15 min").tag(15)
                Text("25 min").tag(25)
                Text("40 min").tag(40)
            }
            .pickerStyle(.segmented)
            Text("Changing time, level or equipment rebuilds the steps below. Edit individual steps afterwards.")
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
        }
    }
    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "What you have", subtitle: "No equipment? We’ll offer training alternatives.")
            DisclosureGroup("\(preferences.equipment.count) equipment options selected") {
                VStack(spacing: 8) {
                    ForEach(Equipment.allCases) { equipment in
                        ChoiceRow(title: equipment.title, selected: preferences.equipment.contains(equipment)) {
                            if preferences.equipment.contains(equipment) { preferences.equipment.remove(equipment) }
                            else { preferences.equipment.insert(equipment) }
                        }
                    }
                }
                .padding(.top, 12)
            }
            .font(.body).trainingPanel(padding: 16)
        }
    }
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Fine-tune your session", subtitle: "Tap a movement to change its target or choose an alternative.")
            Stepper("\(draft.rounds) \(draft.rounds == 1 ? "round" : "rounds") · ~\(draft.estimatedMinutes) min", value: $draft.rounds, in: 1...12)
                .font(.body.weight(.medium)).trainingPanel(padding: 16)
            stepGroup("Warm-up", steps: draft.warmup, phase: .warmup)
            stepGroup("Main work · repeats each round", steps: draft.main, phase: .work)
            stepGroup("Cool down", steps: draft.cooldown, phase: .cooldown)
        }
    }
    private func stepGroup(_ title: String, steps: [WorkoutStep], phase: TrainingPhase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            ForEach(steps) { step in
                Button { editingStep = StepEditorDestination(step: step, phase: phase, isNew: false) } label: {
                    HStack(alignment: .center, spacing: 12) {
                        ExerciseDemoThumbnail(exercise: step.exercise)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(step.title).font(.body.weight(.medium)).foregroundStyle(TrainingTheme.primary)
                            Text(step.targetText(units: preferences.units)).font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                            if step.substitutionFor != nil {
                                Text("Training alternative").font(.caption).foregroundStyle(TrainingTheme.mint)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "pencil").foregroundStyle(TrainingTheme.secondary)
                    }
                    .trainingPanel(padding: 16)
                }
                .buttonStyle(.plain)
            }
            Button {
                let step = ExerciseCatalog.step(phase == .work ? "squat" : "walk")
                editingStep = StepEditorDestination(step: step, phase: phase, isNew: true)
            } label: { Label("Add a step", systemImage: "plus.circle").font(.body).frame(minHeight: 44) }
        }
    }
    private var resetSection: some View {
        Button("Reset to starter steps") { confirmReset = true }
            .font(.body).foregroundStyle(TrainingTheme.secondary).frame(minHeight: 44)
    }
    private var saveBar: some View {
        Button("Use this workout") {
            if repository.saveWorkout(draft, preferences: preferences) { dismiss() }
        }
        .buttonStyle(TrainingButtonStyle())
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(TrainingTheme.background)
    }
    private func rebuild() { draft = WorkoutFactory.make(draft.family, preferences: preferences) }
    private func canDelete(_ destination: StepEditorDestination) -> Bool {
        if destination.isNew { return false }
        switch destination.phase {
        case .warmup: return draft.warmup.count > 1
        case .work, .rest: return draft.main.count > 1
        case .cooldown: return draft.cooldown.count > 1
        }
    }
    private func apply(_ step: WorkoutStep, destination: StepEditorDestination) {
        switch destination.phase {
        case .warmup: replace(step, in: &draft.warmup)
        case .work, .rest: replace(step, in: &draft.main)
        case .cooldown: replace(step, in: &draft.cooldown)
        }
    }
    private func replace(_ step: WorkoutStep, in steps: inout [WorkoutStep]) {
        if let index = steps.firstIndex(where: { $0.id == step.id }) { steps[index] = step }
        else { steps.append(step) }
    }
    private func remove(_ destination: StepEditorDestination) {
        switch destination.phase {
        case .warmup: draft.warmup.removeAll { $0.id == destination.step.id }
        case .work, .rest: draft.main.removeAll { $0.id == destination.step.id }
        case .cooldown: draft.cooldown.removeAll { $0.id == destination.step.id }
        }
    }
}

private struct StepEditorDestination: Identifiable {
    let step: WorkoutStep
    let phase: TrainingPhase
    let isNew: Bool
    var id: String { step.id }
}
