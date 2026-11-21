import SwiftUI

struct WorkoutChooserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlusPurchaseStore.self) private var plus
    let repository: TrainingRepository
    @State private var builder: BuilderPresentation?
    @State private var deleting: WorkoutDefinition?
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView { content.padding(20) }
            .navigationTitle("Choose a session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(item: $builder) { destination in
                PlusFeatureView(repository: repository, feature: .builder, workout: destination.workout)
            }
            .confirmationDialog("Delete this custom workout?", isPresented: $confirmDelete, presenting: deleting) { workout in
                Button("Delete workout", role: .destructive) { _ = repository.deleteCustomWorkout(workout.id) }
            } message: { _ in Text("Only the template is removed. Saved results and any active workout stay safe.") }
            .trainingScreen()
        }
    }
    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Choose what feels right today.").font(.title2.weight(.bold))
            Text("\(WorkoutFamily.starters.count) free starters, with a fresh shuffled option on Today. Adjust any session or choose a lighter day.")
                .font(.body).foregroundStyle(TrainingTheme.secondary)
            createButton
            ForEach(repository.workouts) { workout in
                VStack(alignment: .leading, spacing: 8) {
                    Button { select(workout) } label: { workoutCard(workout) }.buttonStyle(.plain)
                    if workout.family == .custom { customActions(workout) }
                }
            }
            if let error = repository.storageError { Text(error).font(.body) }
        }
    }
    private var createButton: some View {
        Button { builder = BuilderPresentation(workout: nil) } label: {
            HStack {
                Label("Create a custom workout", systemImage: "plus.circle.fill").font(.headline)
                Spacer()
                Text("PLUS").font(.caption.bold())
            }.padding(18).frame(minHeight: 64)
                .background(TrainingTheme.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(TrainingTheme.mint.opacity(0.4)))
        }.buttonStyle(.plain).foregroundStyle(TrainingTheme.mint)
    }
    private func customActions(_ workout: WorkoutDefinition) -> some View {
        HStack(spacing: 20) {
            Button("Edit") { builder = BuilderPresentation(workout: workout) }.frame(minHeight: 44)
            Button("Duplicate") {
                var copy = workout
                copy.id = "custom-" + UUID().uuidString
                copy.title = String((workout.title + " copy").prefix(80))
                builder = BuilderPresentation(workout: copy)
            }.frame(minHeight: 44)
            Spacer()
            Button { deleting = workout; confirmDelete = true } label: {
                Image(systemName: "trash").frame(width: 44, height: 44)
            }.accessibilityLabel("Delete \(workout.title)")
        }.font(.subheadline).padding(.horizontal, 12)
    }
    private func workoutCard(_ workout: WorkoutDefinition) -> some View {
        HStack(alignment: .top, spacing: 14) {
            SymbolTile(symbol: workout.family.symbol)
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: workout.family.category)
                Text(workout.title).font(.title3.weight(.semibold))
                Text(workout.purpose).font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                Text("~\(workout.estimatedMinutes) min · \(workout.level.title)")
                    .font(.subheadline.weight(.medium)).foregroundStyle(TrainingTheme.mint)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if repository.selectedWorkout?.id == workout.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(TrainingTheme.mint) }
        }
        .trainingPanel().foregroundStyle(TrainingTheme.primary)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(repository.selectedWorkout?.id == workout.id ? .isSelected : [])
    }
    private func select(_ workout: WorkoutDefinition) {
        if repository.selectWorkout(workout.id) { dismiss() }
    }
}

private struct BuilderPresentation: Identifiable {
    let workout: WorkoutDefinition?
    var id: String { workout?.id ?? "new-workout" }
}
