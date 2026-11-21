import SwiftUI

struct WorkoutStepEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let units: UnitSystem
    let canDelete: Bool
    let save: (WorkoutStep) -> Void
    let delete: () -> Void
    private let original: WorkoutStep
    @State private var draft: WorkoutStep
    @State private var targetValue: String
    @State private var loadValue: String
    @State private var validationMessage: String?
    @State private var confirmDelete = false
    @State private var guide: Exercise?

    init(step: WorkoutStep, units: UnitSystem, canDelete: Bool,
         save: @escaping (WorkoutStep) -> Void, delete: @escaping () -> Void) {
        self.units = units
        self.canDelete = canDelete
        self.save = save
        self.delete = delete
        original = step
        _draft = State(initialValue: step)
        let quantity = step.targetKind == .distance ? units.distanceValue(step.target) : step.target
        _targetValue = State(initialValue: TrainingFormat.number(quantity))
        _loadValue = State(initialValue: TrainingFormat.number(units.loadValue(step.loadKg)))
    }
    var body: some View {
        NavigationStack {
            Form {
                movementSection
                demoSection
                targetSection
                guidanceSection
                if let message = validationMessage { Section { Text(message).foregroundStyle(TrainingTheme.mint) } }
                if canDelete {
                    Section { Button("Remove this step", role: .destructive) { confirmDelete = true } }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit movement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: saveStep).fontWeight(.semibold) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hideKeyboard() } }
            }
            .onChange(of: draft.exerciseID) { _, _ in changeExercise() }
            .onChange(of: draft.targetKind) { old, new in changeTarget(from: old, to: new) }
            .confirmationDialog("Remove this step?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Remove step", role: .destructive) { delete(); dismiss() }
            }
            .trainingScreen()
        }
    }
    private var movementSection: some View {
        Section("Movement") {
            Picker("Exercise", selection: $draft.exerciseID) {
                ForEach(ExerciseCatalog.all) { exercise in Text(exercise.title).tag(exercise.id) }
            }
            if let equipment = draft.exercise.equipment {
                Label(equipment.title, systemImage: "dumbbell").foregroundStyle(TrainingTheme.secondary)
            } else { Text("No equipment needed").foregroundStyle(TrainingTheme.secondary) }
            if let original = draft.substitutionFor {
                Text("Training alternative to \(original.lowercased()). This is not the official race movement.")
                    .font(.subheadline).foregroundStyle(TrainingTheme.mint)
            }
        }
        .listRowBackground(TrainingTheme.surface)
    }
    private var targetSection: some View {
        Section {
            Picker("Target type", selection: $draft.targetKind) {
                ForEach(TargetKind.allCases) { Text($0.title).tag($0) }
            }
            HStack {
                Text(targetLabel)
                Spacer()
                TextField("Target", text: $targetValue).keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing).frame(minWidth: 80)
                    .accessibilityLabel(targetLabel)
            }
            HStack {
                Text("Load (\(units.loadUnit))")
                Spacer()
                TextField("Optional load", text: $loadValue).keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing).frame(minWidth: 80)
                    .accessibilityLabel("Load in \(units.loadUnit)")
            }
        } header: { Text("Your target") } footer: {
            Text("Enter 0 for no added weight. Farmer’s carry loads are per hand; sled loads are added weight. Only timed steps advance automatically.")
        }
        .listRowBackground(TrainingTheme.surface)
    }
    private var demoSection: some View {
        Section("See how to move") {
            Button { guide = draft.exercise } label: {
                HStack(spacing: 14) {
                    ExerciseDemoThumbnail(exercise: draft.exercise, size: 84)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Watch the illustrated loop").font(.headline).foregroundStyle(TrainingTheme.primary)
                        Text("Pause or slow down the demo.").font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "play.circle.fill").foregroundStyle(TrainingTheme.accent)
                }.padding(.vertical, 4)
            }.buttonStyle(.plain)
        }
        .listRowBackground(TrainingTheme.surface)
        .sheet(item: $guide) { ExerciseGuideView(exercise: $0) }
    }
    private var guidanceSection: some View {
        Section("How to move") {
            Text(draft.exercise.cues).font(.body)
            Text("Use a comfortable range of motion. Training targets are not official race standards.")
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
        }
        .listRowBackground(TrainingTheme.surface)
    }
    private var targetLabel: String {
        switch draft.targetKind {
        case .time: "Seconds"
        case .distance: "Distance (\(units.distanceUnit))"
        case .repetitions: "Repetitions"
        }
    }
    private func changeExercise() {
        let exercise = draft.exercise
        draft.substitutionFor = draft.exerciseID == original.exerciseID ? original.substitutionFor : original.title
        draft.targetKind = exercise.defaultKind
        draft.target = exercise.defaultTarget
        let quantity = draft.targetKind == .distance ? units.distanceValue(draft.target) : draft.target
        targetValue = TrainingFormat.number(quantity)
        loadValue = "0"
    }
    private func changeTarget(from old: TargetKind, to new: TargetKind) {
        guard old != new else { return }
        let value: Double = new == .time ? 60 : (new == .distance ? 100 : 10)
        draft.target = value
        targetValue = TrainingFormat.number(new == .distance ? units.distanceValue(value) : value)
    }
    private func saveStep() {
        guard let input = NumericInput.parse(targetValue), input > 0,
              let load = NumericInput.parse(loadValue.isEmpty ? "0" : loadValue), load >= 0 else {
            validationMessage = "Enter a target greater than zero and a load of zero or more."
            return
        }
        let canonical = draft.targetKind == .distance ? units.meters(input) : input
        guard canonical <= (draft.targetKind == .time ? 7200 : (draft.targetKind == .distance ? 42000 : 1000)),
              units.kilograms(load) <= 500 else {
            validationMessage = "Choose a practical training target and load."
            return
        }
        draft.target = draft.targetKind == .repetitions ? max(1, canonical.rounded()) : canonical
        draft.loadKg = units.kilograms(load)
        if draft.targetKind == .time { draft.estimatedSeconds = draft.target }
        else if draft.targetKind == .repetitions { draft.estimatedSeconds = draft.target * 4 }
        else { draft.estimatedSeconds = draft.target * (draft.exerciseID == "run" ? 0.45 : (draft.exerciseID == "row" || draft.exerciseID == "ski" ? 0.5 : 1.1)) }
        save(draft)
        dismiss()
    }
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

enum NumericInput {
    static func parse(_ text: String) -> Double? {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: text), number.doubleValue.isFinite { return number.doubleValue }
        guard let number = Double(text.replacingOccurrences(of: ",", with: ".")), number.isFinite else { return nil }
        return number
    }
}
