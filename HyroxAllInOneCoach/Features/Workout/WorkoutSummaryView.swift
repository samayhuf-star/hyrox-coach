import SwiftUI

struct WorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let repository: TrainingRepository
    let engine: WorkoutSessionEngine
    let isNew: Bool
    private let original: SessionRecord
    @State private var draft: SessionRecord
    @State private var editor: SummaryEditor?
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    @State private var confirmClose = false

    init(repository: TrainingRepository, engine: WorkoutSessionEngine, record: SessionRecord, isNew: Bool) {
        self.repository = repository
        self.engine = engine
        self.isNew = isNew
        original = record
        _draft = State(initialValue: record)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    celebration
                    stats
                    effortSection
                    noteSection
                    resultSection
                    actions
                    if let error = repository.storageError { Text(error).font(.body) }
                    Text("Phone timer and manually confirmed targets. No sensor measurements. Duration includes any time spent revisiting steps; splits show the latest attempt.")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }
                .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle(isNew ? "Workout summary" : "Saved session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(isNew ? "Later" : "Close", action: close) }
                ToolbarItem(placement: .primaryAction) { Button("Edit details") { editor = .details } }
            }
            .sheet(item: $editor) { destination in editorView(destination) }
            .confirmationDialog("Delete this saved session?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete session", role: .destructive) { if repository.deleteSession(draft.id) { dismiss() } }
            } message: { Text("The session and its contribution to weekly progress will be removed. Your workout template won’t change.") }
            .confirmationDialog("Discard this unsaved workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) { if engine.discard() { dismiss() } }
            } message: { Text("This result won’t be added to your history.") }
            .confirmationDialog("Leave without saving changes?", isPresented: $confirmClose, titleVisibility: .visible) {
                Button("Discard edits", role: .destructive) { dismiss() }
                Button("Save changes", action: save)
            }
            .onChange(of: draft) { _, record in if isNew { engine.updateSummary(record) } }
            .interactiveDismissDisabled(!isNew && draft != original)
            .trainingScreen()
        }
    }
    private var celebration: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SymbolTile(symbol: "checkmark.seal.fill")
                Spacer()
                StatusPill(text: isNew ? "Ready to save" : "Saved on iPhone", symbol: isNew ? nil : "checkmark")
            }
            Text(draft.completedCount > 0 ? "You showed up." : "Listen to your body.")
                .font(.trainingDisplay()).textCase(.uppercase)
            Text(draft.workout.title).font(.title3.weight(.semibold))
            Text(draft.startedAt, format: .dateTime.month(.wide).day().hour().minute())
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            if draft.endedEarly {
                Text("Finished early. The work you did still matters.")
                    .font(.body).foregroundStyle(TrainingTheme.secondary)
            } else {
                Text("One session closer to a stronger you. Rest and recover well.")
                    .font(.body).foregroundStyle(TrainingTheme.secondary)
            }
        }
    }
    private var stats: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Duration").font(.body).foregroundStyle(TrainingTheme.secondary)
                Spacer()
                Text(TrainingFormat.clock(draft.durationSeconds)).font(.title.weight(.semibold).monospacedDigit())
            }
            Divider().overlay(TrainingTheme.border)
            statRow("Completed", value: "\(draft.completedCount) / \(draft.workout.expandedSteps.count) steps")
            statRow("Skipped", value: "\(draft.skippedCount) steps")
            let unreached = max(0, draft.workout.expandedSteps.count - draft.results.count)
            if unreached > 0 { statRow("Not reached", value: "\(unreached) steps") }
        }
        .trainingPanel()
    }
    private func statRow(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack { Text(title).foregroundStyle(TrainingTheme.secondary); Spacer(); Text(value) }
            VStack(alignment: .leading, spacing: 4) { Text(title).foregroundStyle(TrainingTheme.secondary); Text(value) }
        }
        .font(.body).accessibilityElement(children: .combine)
    }
    private var effortSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "How did it feel?", subtitle: "Optional. There’s no wrong answer.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 10) {
                ForEach(SessionEffort.allCases) { effort in
                    Button {
                        draft.effort = draft.effort == effort ? nil : effort
                    } label: {
                        Text(effort.title).font(.body.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 50).padding(.horizontal, 8)
                            .foregroundStyle(draft.effort == effort ? TrainingTheme.mint : TrainingTheme.primary)
                            .background(TrainingTheme.surface, in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(draft.effort == effort ? TrainingTheme.mint : TrainingTheme.border))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(draft.effort == effort ? .isSelected : [])
                }
            }
        }
    }
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "A note for next time")
            TextField("What felt good? What would you change?", text: $draft.note, axis: .vertical)
                .font(.body).lineLimit(3...6).trainingPanel(padding: 16)
                .accessibilityLabel("Optional session note")
        }
    }
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Step-by-step", subtitle: "Tap any split to review or correct it.")
            VStack(spacing: 0) {
                ForEach(draft.workout.expandedSteps) { step in
                    Button { editor = .split(step) } label: {
                        SplitResultRow(step: step, result: draft.results.first { $0.id == step.id }, units: repository.preferences.units)
                    }
                    .buttonStyle(.plain)
                    if step.id != draft.workout.expandedSteps.last?.id { Divider().overlay(TrainingTheme.border) }
                }
            }
            .trainingPanel(padding: 16)
        }
    }
    private var actions: some View {
        VStack(spacing: 10) {
            if isNew {
                if !draft.results.isEmpty {
                    Button { engine.undo() } label: { Label("Return to the last step", systemImage: "arrow.uturn.backward") }
                        .font(.body).frame(minHeight: 44)
                }
                Button("Discard workout", role: .destructive) { confirmDiscard = true }.font(.body).frame(minHeight: 44)
            } else {
                Button("Delete saved session", role: .destructive) { confirmDelete = true }.font(.body).frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity)
    }
    @ViewBuilder private var saveBar: some View {
        if isNew || draft != original {
            Button(isNew ? "Save workout" : "Save changes", action: save)
                .buttonStyle(TrainingButtonStyle())
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(TrainingTheme.background)
        }
    }
    @ViewBuilder private func editorView(_ destination: SummaryEditor) -> some View {
        switch destination {
        case .details: SessionDetailsEditorView(record: $draft)
        case .split(let step):
            SplitResultEditorView(step: step, result: draft.results.first { $0.id == step.id }, units: repository.preferences.units) { result in
                draft.results.removeAll { $0.id == result.id }
                draft.results.append(result)
                let order = draft.workout.expandedSteps.map(\.id)
                draft.results.sort { (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0) }
            }
        }
    }
    private func save() {
        if repository.saveSession(draft, finishingActive: isNew) { dismiss() }
    }
    private func close() {
        if !isNew, draft != original { confirmClose = true }
        else { dismiss() }
    }
}

private enum SummaryEditor: Identifiable {
    case details, split(ExpandedStep)
    var id: String {
        switch self {
        case .details: "details"
        case .split(let step): "split-\(step.id)"
        }
    }
}

struct SplitResultRow: View {
    let step: ExpandedStep
    let result: StepResult?
    let units: UnitSystem
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: statusSymbol).font(.body)
                .foregroundStyle(result?.status == .completed ? TrainingTheme.mint : TrainingTheme.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(step.step.title).font(.body.weight(.medium)).foregroundStyle(TrainingTheme.primary)
                Text(phaseText).font(.caption).foregroundStyle(TrainingTheme.secondary)
                Text(actualText).font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 5) {
                Text(result.map { TrainingFormat.clock($0.elapsedSeconds) } ?? "—")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(TrainingTheme.primary)
                Text(result?.status.title ?? "Not reached").font(.caption).foregroundStyle(TrainingTheme.secondary)
            }
        }
        .padding(.vertical, 14).accessibilityElement(children: .combine)
    }
    private var phaseText: String {
        if let round = step.round { return "\(step.phase.title) · Round \(round)" }
        return step.phase.title
    }
    private var statusSymbol: String {
        if result?.status == .completed { return "checkmark.circle.fill" }
        return result == nil ? "circle.dashed" : "forward.end.circle"
    }
    private var actualText: String {
        guard let result else { return "Target: \(step.step.targetText(units: units))" }
        var parts: [String] = []
        if let target = result.actualTarget {
            if step.step.targetKind == .distance { parts.append("\(TrainingFormat.number(units.distanceValue(target))) \(units.distanceUnit) · manual") }
            else if step.step.targetKind == .repetitions { parts.append("\(TrainingFormat.number(target)) reps · manual") }
        }
        if let load = result.actualLoadKg { parts.append("\(TrainingFormat.number(units.loadValue(load))) \(units.loadUnit)") }
        return parts.isEmpty ? "Target: \(step.step.targetText(units: units))" : parts.joined(separator: " · ")
    }
}
