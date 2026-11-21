import SwiftUI

struct TrainingPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    let repository: TrainingRepository
    @State private var draft: AthletePreferences
    @State private var showingSetup = false
    @State private var showingJourney = false
    @State private var showingPlus = false
    @Environment(PlusPurchaseStore.self) private var plus

    init(repository: TrainingRepository) {
        self.repository = repository
        _draft = State(initialValue: repository.preferences)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Your journey") {
                    Button { showingSetup = true } label: { Label("Review my setup", systemImage: "person.crop.circle") }
                    Button { showingJourney = true } label: { Label("Weekly rhythm & rewards", systemImage: "sparkles") }
                }.listRowBackground(TrainingTheme.surface)
                Section {
                    Picker("Units", selection: $draft.units) {
                        ForEach(UnitSystem.allCases) { Text($0.title).tag($0) }
                    }
                } header: { Text("Measurements") } footer: {
                    Text("Distance and load are converted for display. Changing units doesn’t change your saved targets or results.")
                }
                .listRowBackground(TrainingTheme.surface)
                Section {
                    Toggle("Haptic transitions", isOn: $draft.haptics)
                    Toggle("Sound transitions", isOn: $draft.sound)
                } header: { Text("Workout cues") } footer: {
                    Text("A short cue when a step changes while the app is open. Sound follows your device’s audio settings. There are no background voice cues.")
                }
                .listRowBackground(TrainingTheme.surface)
                Section("Membership") {
                    Button { showingPlus = true } label: {
                        Label(plus.isPlus ? "Manage Hybrid Plus" : "Discover Hybrid Plus", systemImage: "sparkles")
                    }
                    Text("Custom workout creation and detailed insights. Daily training, starter edits, saved history and rewards stay free.")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }.listRowBackground(TrainingTheme.surface)
                Section("Your data") {
                    Label("Saved on this iPhone", systemImage: "iphone")
                    Label("Works without an account", systemImage: "person.crop.circle.badge.checkmark")
                    Text("Workouts, history and your active session stay on this device. This version does not connect to Apple Health or Apple Watch.")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }
                .listRowBackground(TrainingTheme.surface)
                Section("Train sustainably") {
                    SafetyNote()
                    Text("You can scale movements, take extra rest, or choose a lighter session. These starter workouts are not medical advice or personalized coaching.")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }
                .listRowBackground(TrainingTheme.surface)
                if let error = repository.storageError { Section { Text(error) } }
            }
            .font(.body)
            .scrollContentBackground(.hidden)
            .navigationTitle("Training preferences")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSetup, onDismiss: { draft = repository.preferences }) {
                OnboardingView(repository: repository, isReview: true)
            }
            .sheet(isPresented: $showingJourney) { JourneySettingsView(repository: repository) }
            .sheet(isPresented: $showingPlus) { PlusPaywallView() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if repository.savePreferences(draft) { dismiss() } }
                        .fontWeight(.semibold)
                }
            }
            .trainingScreen()
        }
    }
}

struct SessionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let repository: TrainingRepository
    let engine: WorkoutSessionEngine
    @State private var selected: SessionRecord?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if repository.sessions.isEmpty {
                        ContentUnavailableView("A fresh start", systemImage: "checkmark.seal",
                                               description: Text("Your saved sessions will appear here."))
                    }
                    ForEach(repository.sessions) { record in
                        Button { selected = record } label: { SessionHistoryRow(record: record).trainingPanel(padding: 16) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Your sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(item: $selected) { record in
                WorkoutSummaryView(repository: repository, engine: engine, record: record, isNew: false)
            }
            .trainingScreen()
        }
    }
}
