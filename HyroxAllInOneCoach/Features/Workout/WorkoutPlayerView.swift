import SwiftUI
import UIKit

struct WorkoutPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let repository: TrainingRepository
    let engine: WorkoutSessionEngine
    @State private var confirmEnd = false
    @State private var showingActuals = false
    @State private var guide: Exercise?

    var body: some View {
        Group {
            if let record = engine.active?.summary {
                WorkoutSummaryView(repository: repository, engine: engine, record: record, isNew: true)
                    .id(record.id)
            } else {
                NavigationStack {
                    if let session = engine.active, let current = session.current {
                        player(session: session, current: current).trainingScreen()
                    } else {
                        ContentUnavailableView("You’re all set", systemImage: "checkmark.circle")
                            .onAppear { dismiss() }
                            .trainingScreen()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .sheet(item: $guide) { ExerciseGuideView(exercise: $0, sessionPaused: true) }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = engine.active?.summary == nil }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: engine.active?.summary?.id) { _, id in UIApplication.shared.isIdleTimerDisabled = id == nil }
        .onChange(of: scenePhase) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = phase == .active && engine.active?.summary == nil
        }
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private func player(session: ActiveSession, current: ExpandedStep) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                progress(session)
                currentInstruction(session: session, current: current)
                    .id(current.id)
                    .transition(reduceMotion ? .opacity : .offset(y: 12).combined(with: .opacity))
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.9), value: current.id)
                ExerciseDemoPlayer(exercise: current.step.exercise, autoplay: guide == nil) {
                    if engine.active?.runningSince != nil { engine.togglePause() }
                    guide = engine.active?.current?.step.exercise
                }.id(current.id)
                WorkoutClockView(session: session, current: current)
                if session.autoPaused == true {
                    Label("Paused for you after a long break on this step. Tap resume when you’re ready; the extra time wasn’t counted.",
                          systemImage: "pause.circle")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }
                movementGuidance(current)
                nextPreview(session)
                if let error = repository.storageError { Text(error).font(.body) }
                Text("Your session is saved as you go. Returning to Today keeps the timer running unless you pause it.")
                    .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }
            .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) { controls(session: session, current: current) }
        .background { TrainingBackdrop() }
        .navigationTitle("Your workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Label("Today", systemImage: "chevron.down") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("End") { confirmEnd = true }.foregroundStyle(TrainingTheme.secondary)
                    .accessibilityLabel("End workout early")
            }
        }
        .confirmationDialog("Finish this workout early?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("Finish & review", action: engine.endEarly)
            Button("Keep training", role: .cancel) {}
        } message: { Text("Review and save the work you’ve done. Any unfinished steps stay clearly marked.") }
        .sheet(isPresented: $showingActuals) {
            ActualTargetEditorView(engine: engine, step: current.step, units: repository.preferences.units,
                                   actualTarget: session.actualTarget, actualLoadKg: session.actualLoadKg)
        }
    }
    private func progress(_ session: ActiveSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack { Eyebrow(text: session.workout.family.category); Spacer(); stepCount(session) }
                VStack(alignment: .leading, spacing: 6) { Eyebrow(text: session.workout.family.category); stepCount(session) }
            }
            ProgressView(value: Double(session.cursor), total: Double(max(1, session.steps.count)))
                .tint(TrainingTheme.mint)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: session.cursor)
                .accessibilityLabel("Workout progress")
                .accessibilityValue("\(session.cursor) of \(session.steps.count) steps recorded")
        }
    }
    private func stepCount(_ session: ActiveSession) -> some View {
        Text("Step \(session.cursor + 1) of \(session.steps.count)")
            .font(.subheadline.monospacedDigit()).foregroundStyle(TrainingTheme.secondary)
    }
    private func currentInstruction(session: ActiveSession, current: ExpandedStep) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusPill(text: current.phase.title, symbol: current.phase == .rest ? "pause" : nil)
                if let round = current.round {
                    Text("Round \(round) / \(session.workout.rounds)").font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }
            }
            Text(current.step.title).font(.largeTitle.weight(.heavy)).tracking(-1).fixedSize(horizontal: false, vertical: true)
            Text(current.step.targetText(units: repository.preferences.units)).font(.title2.weight(.semibold))
                .foregroundStyle(TrainingTheme.mint)
            if let original = current.step.substitutionFor {
                Text("Training alternative to \(original.lowercased()), not an official race movement.")
                    .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }
        }
    }
    private func movementGuidance(_ current: ExpandedStep) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How to move", systemImage: "figure.mind.and.body").font(.headline)
            Text(current.step.exercise.cues).font(.body).foregroundStyle(TrainingTheme.secondary)
            if current.step.targetKind != .time || current.step.loadKg > 0 {
                Button { showingActuals = true } label: {
                    Label("Log actual distance, reps or load", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }
            }
        }
        .trainingPanel()
    }
    @ViewBuilder private func nextPreview(_ session: ActiveSession) -> some View {
        let nextIndex = session.cursor + 1
        if session.steps.indices.contains(nextIndex) {
            let next = session.steps[nextIndex]
            HStack(alignment: .center, spacing: 14) {
                ExerciseDemoThumbnail(exercise: next.step.exercise)
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "Next up")
                    Text(next.step.title).font(.headline)
                    Text(next.step.targetText(units: repository.preferences.units)).font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }
            }
        } else {
            Label("Next up: your workout summary", systemImage: "checkmark.seal").font(.body)
        }
    }
    private func controls(session: ActiveSession, current: ExpandedStep) -> some View {
        VStack(spacing: 10) {
            Button {
                if session.isPaused || current.step.targetKind == .time { engine.togglePause() }
                else { engine.advance() }
            } label: {
                Label(primaryTitle(session, current: current), systemImage: primarySymbol(session, current: current))
            }
            .buttonStyle(TrainingButtonStyle())
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 22) { secondaryControls(session: session, current: current) }
                VStack(spacing: 3) { secondaryControls(session: session, current: current) }
            }
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
        .background(TrainingTheme.background)
    }
    @ViewBuilder private func secondaryControls(session: ActiveSession, current: ExpandedStep) -> some View {
        if current.step.targetKind != .time, !session.isPaused {
            Button(action: engine.togglePause) { Label("Pause", systemImage: "pause") }
        }
        Button { engine.advance(skipped: true) } label: { Label("Skip", systemImage: "forward.end") }
        if !session.results.isEmpty {
            Button(action: engine.undo) { Label("Undo", systemImage: "arrow.uturn.backward") }
                .accessibilityHint("Returns to the previous step, pauses and restarts its timer.")
        }
    }
    private func primaryTitle(_ session: ActiveSession, current: ExpandedStep) -> String {
        if session.isPaused { return "Resume workout" }
        return current.step.targetKind == .time ? "Pause workout" : "Done / Next"
    }
    private func primarySymbol(_ session: ActiveSession, current: ExpandedStep) -> String {
        if session.isPaused { return "play.fill" }
        return current.step.targetKind == .time ? "pause.fill" : "checkmark"
    }
}
