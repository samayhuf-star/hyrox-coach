import SwiftUI

struct ActualTargetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let engine: WorkoutSessionEngine
    let step: WorkoutStep
    let units: UnitSystem
    @State private var target: String
    @State private var load: String
    @State private var error: String?

    init(engine: WorkoutSessionEngine, step: WorkoutStep, units: UnitSystem, actualTarget: Double?, actualLoadKg: Double?) {
        self.engine = engine
        self.step = step
        self.units = units
        let value = actualTarget ?? step.target
        _target = State(initialValue: TrainingFormat.number(step.targetKind == .distance ? units.distanceValue(value) : value))
        _load = State(initialValue: TrainingFormat.number(units.loadValue(actualLoadKg ?? step.loadKg)))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(step.title).font(.headline)
                    if step.targetKind != .time {
                        NumericEntryRow(title: step.targetKind == .distance ? "Distance (\(units.distanceUnit))" : "Repetitions", text: $target)
                    }
                    NumericEntryRow(title: "Load (\(units.loadUnit))", text: $load)
                } footer: {
                    Text("These are manually entered results. Logging a value does not finish the step; use Done / Next when you’re ready.")
                }
                .listRowBackground(TrainingTheme.surface)
                if let error { Section { Text(error).foregroundStyle(TrainingTheme.mint) } }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("What you did")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); KeyboardDoneButton() }
            }
            .trainingScreen()
        }
        .onAppear { if engine.active?.isPaused == false { engine.togglePause() } }
    }
    private func save() {
        guard let quantity = NumericInput.parse(target), quantity >= 0,
              let weight = NumericInput.parse(load), weight >= 0,
              quantity <= 100000, units.kilograms(weight) <= 500 else {
            error = "Enter a valid quantity and a load of zero or more."
            return
        }
        let canonical = step.targetKind == .distance ? units.meters(quantity) : quantity.rounded()
        engine.logActual(target: step.targetKind == .time ? nil : canonical, load: units.kilograms(weight))
        if engine.repository.storageError == nil { dismiss() }
        else { error = engine.repository.storageError }
    }
}

struct SplitResultEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let step: ExpandedStep
    let units: UnitSystem
    let saveResult: (StepResult) -> Void
    @State private var status: StepStatus
    @State private var minutes: String
    @State private var seconds: String
    @State private var target: String
    @State private var load: String
    @State private var error: String?

    init(step: ExpandedStep, result: StepResult?, units: UnitSystem, saveResult: @escaping (StepResult) -> Void) {
        self.step = step
        self.units = units
        self.saveResult = saveResult
        _status = State(initialValue: result?.status ?? .completed)
        let elapsed = Int(result?.elapsedSeconds ?? 0)
        _minutes = State(initialValue: String(elapsed / 60))
        _seconds = State(initialValue: String(elapsed % 60))
        let value = result?.actualTarget
        _target = State(initialValue: value.map { TrainingFormat.number(step.step.targetKind == .distance ? units.distanceValue($0) : $0) } ?? "")
        _load = State(initialValue: result?.actualLoadKg.map { TrainingFormat.number(units.loadValue($0)) } ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(step.step.title).font(.headline)
                    Text("Planned: \(step.step.targetText(units: units))").foregroundStyle(TrainingTheme.secondary)
                    Picker("Status", selection: $status) { ForEach(StepStatus.allCases) { Text($0.title).tag($0) } }
                }
                .listRowBackground(TrainingTheme.surface)
                Section("Split duration") {
                    NumericEntryRow(title: "Minutes", text: $minutes)
                    NumericEntryRow(title: "Seconds", text: $seconds)
                }
                .listRowBackground(TrainingTheme.surface)
                Section {
                    if step.step.targetKind != .time {
                        NumericEntryRow(title: step.step.targetKind == .distance ? "Actual distance (\(units.distanceUnit))" : "Actual repetitions", text: $target)
                    }
                    NumericEntryRow(title: "Actual load (\(units.loadUnit))", text: $load)
                } header: { Text("Manual results") } footer: {
                    Text("Leave quantities blank if you didn’t record them. This edits the result, not your workout target. Changing a split does not change the total duration; use Edit details to correct that.")
                }
                .listRowBackground(TrainingTheme.surface)
                if let error { Section { Text(error).foregroundStyle(TrainingTheme.mint) } }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Correct a split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); KeyboardDoneButton() }
            }
            .trainingScreen()
        }
    }
    private func save() {
        guard let mins = NumericInput.parse(minutes), let secs = NumericInput.parse(seconds),
              mins >= 0, mins <= 1440, secs >= 0, secs < 60,
              target.isEmpty || (NumericInput.parse(target).map { $0 >= 0 && $0 <= 100000 } ?? false),
              load.isEmpty || (NumericInput.parse(load).map { $0 >= 0 && units.kilograms($0) <= 500 } ?? false) else {
            error = "Use valid numbers. Seconds must be between 0 and 59. Quantities and load cannot be negative."
            return
        }
        let enteredTarget = NumericInput.parse(target)
        let canonical = enteredTarget.map { step.step.targetKind == .distance ? units.meters($0) : $0.rounded() }
        let kg = NumericInput.parse(load).map { units.kilograms($0) }
        saveResult(StepResult(id: step.id, status: status, elapsedSeconds: mins * 60 + secs,
                              actualTarget: step.step.targetKind == .time ? nil : canonical, actualLoadKg: kg))
        dismiss()
    }
}

struct SessionDetailsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var record: SessionRecord
    @State private var draft: SessionRecord
    @State private var minutes: String
    @State private var seconds: String
    @State private var error: String?

    init(record: Binding<SessionRecord>) {
        _record = record
        _draft = State(initialValue: record.wrappedValue)
        let elapsed = Int(record.wrappedValue.durationSeconds)
        _minutes = State(initialValue: String(elapsed / 60))
        _seconds = State(initialValue: String(elapsed % 60))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Session title", text: $draft.workout.title)
                    DatePicker("Started", selection: $draft.startedAt, in: ...Date())
                    Toggle("Finished early", isOn: $draft.endedEarly)
                }
                .listRowBackground(TrainingTheme.surface)
                Section {
                    NumericEntryRow(title: "Minutes", text: $minutes)
                    NumericEntryRow(title: "Seconds", text: $seconds)
                } header: { Text("Total active duration") } footer: {
                    Text("Correcting the total duration does not change individual split times. Saved activity stays manual, not an official race result.")
                }
                .listRowBackground(TrainingTheme.surface)
                if let error { Section { Text(error).foregroundStyle(TrainingTheme.mint) } }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Session details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); KeyboardDoneButton() }
            }
            .trainingScreen()
        }
    }
    private func save() {
        guard !draft.workout.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let mins = NumericInput.parse(minutes), let secs = NumericInput.parse(seconds),
              mins >= 0, mins <= 1440, secs >= 0, secs < 60 else {
            error = "Add a session title and a valid duration. Seconds must be between 0 and 59."
            return
        }
        draft.durationSeconds = mins * 60 + secs
        draft.endedAt = max(draft.startedAt.addingTimeInterval(draft.durationSeconds), draft.endedAt)
        record = draft
        dismiss()
    }
}

struct NumericEntryRow: View {
    let title: String
    @Binding var text: String
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 15) { Text(title); Spacer(); entry }
            VStack(alignment: .leading, spacing: 8) { Text(title); entry }
        }
        .font(.body)
    }
    private var entry: some View {
        TextField("Optional", text: $text).keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing).frame(minWidth: 75)
            .accessibilityLabel(title)
    }
}

struct KeyboardDoneButton: View {
    var body: some View {
        Button("Done") {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
