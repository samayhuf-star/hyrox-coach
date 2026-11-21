import SwiftUI

struct JourneySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let repository: TrainingRepository
    @State private var draft: TrainingJourney
    init(repository: TrainingRepository) {
        self.repository = repository
        _draft = State(initialValue: repository.state.journey ?? TrainingJourney())
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Your direction") {
                    Picker("Training goal", selection: $draft.goal) {
                        ForEach(TrainingGoal.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper("\(draft.weeklyDays) training days / week", value: $draft.weeklyDays, in: 1...4)
                }.listRowBackground(TrainingTheme.surface)
                Section {
                    Toggle("Show points & badges", isOn: $draft.rewardsEnabled)
                } header: { Text("Make it motivating") } footer: {
                    Text("Prefer a quieter experience? Hide rewards anytime. Your workout history stays intact, and you can turn rewards back on later.")
                }.listRowBackground(TrainingTheme.surface)
                Section {
                    Text("Your weekly rhythm is a flexible aim, not a training prescription. The week resets with your device’s calendar; earned XP never resets. Extra rest is always welcome.")
                        .foregroundStyle(TrainingTheme.secondary)
                }.listRowBackground(TrainingTheme.surface)
                if let error = repository.storageError { Section { Text(error) } }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Journey preferences").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if repository.saveJourney(draft) { dismiss() } }.fontWeight(.semibold)
                }
            }
            .trainingScreen()
        }
    }
}
