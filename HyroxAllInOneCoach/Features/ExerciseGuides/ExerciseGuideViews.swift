import SwiftUI

struct ExerciseGuideView: View {
    let exercise: Exercise
    var sessionPaused = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    title
                    ExerciseDemoPlayer(exercise: exercise).id(exercise.id)
                    guidance
                }
                .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .navigationTitle("Movement guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .trainingScreen()
        }
    }
    private var title: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "See it. Then try it.")
            Text(exercise.title).font(.largeTitle.weight(.bold)).tracking(-0.8)
            Label(exercise.equipment?.title ?? "No equipment needed", systemImage: "dumbbell")
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            if sessionPaused {
                Label("Workout paused · resume when you’re ready", systemImage: "pause.circle")
                    .font(.subheadline.weight(.medium)).foregroundStyle(TrainingTheme.accent)
            }
        }
    }
    private var guidance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Keep in mind", systemImage: "info.circle").font(.headline)
            Text(exercise.cues).font(.body).foregroundStyle(TrainingTheme.secondary)
            Text("AI-generated illustrations show general positions, not a precise technique standard. Use a comfortable range and light load. Stop if you feel pain; ask a qualified coach to check unfamiliar movements. Training alternatives are not official race movements.")
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
        }.trainingPanel()
    }
}

struct ExerciseGuideLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Exercise?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    introduction
                    LazyVStack(spacing: 10) {
                        ForEach(ExerciseCatalog.all) { exercise in guideRow(exercise) }
                    }
                }
                .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .navigationTitle("Exercise demos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $selected) { ExerciseGuideView(exercise: $0) }
            .trainingScreen()
        }
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Your movement library")
            Text("A little clarity.\nMore confidence.").font(.largeTitle.weight(.bold)).tracking(-0.8)
            Text("Tap any movement for a looping illustration. Pause, slow it down or explore each position using the arrows. Available offline, with no account or credits.")
                .font(.body).foregroundStyle(TrainingTheme.secondary)
        }.padding(.bottom, 8)
    }
    private func guideRow(_ exercise: Exercise) -> some View {
        Button { selected = exercise } label: {
            HStack(spacing: 14) {
                ExerciseDemoThumbnail(exercise: exercise, size: 76)
                VStack(alignment: .leading, spacing: 5) {
                    Text(exercise.title).font(.headline).foregroundStyle(TrainingTheme.primary)
                    Text(exercise.id == "rest" ? "Rest & breathing cues" : "Looping AI illustration")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").foregroundStyle(TrainingTheme.accent)
            }.trainingPanel(padding: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Learn \(exercise.title)")
    }
}

struct ExerciseGuidesTodayCard: View {
    let workout: WorkoutDefinition
    let open: () -> Void
    private var preview: Exercise {
        workout.main.first(where: { $0.exerciseID != "rest" })?.exercise ?? ExerciseCatalog.find("squat")
    }
    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                ExerciseDemoThumbnail(exercise: preview, size: 84)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Learn the movements").font(.headline).foregroundStyle(TrainingTheme.primary)
                    Text("See every exercise before you start.")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                    Text("AI pose demos · available offline")
                        .font(.caption.weight(.semibold)).foregroundStyle(TrainingTheme.accent)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").foregroundStyle(TrainingTheme.accent)
            }.trainingPanel(padding: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Learn the movements. Open all exercise demos.")
    }
}
