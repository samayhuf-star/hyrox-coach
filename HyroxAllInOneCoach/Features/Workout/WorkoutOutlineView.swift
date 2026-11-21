import SwiftUI

struct WorkoutOutlineView: View {
    let workout: WorkoutDefinition
    let units: UnitSystem
    @State private var expanded = false
    @State private var guide: Exercise?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 18) {
                Text(workout.purpose).font(.body).foregroundStyle(TrainingTheme.secondary)
                WorkoutPhaseStrip(workout: workout)
                block("Warm-up", steps: workout.warmup, number: "01")
                Divider().overlay(TrainingTheme.border)
                block("Main work · \(workout.rounds) \(workout.rounds == 1 ? "round" : "rounds")", steps: workout.main, number: "02")
                Divider().overlay(TrainingTheme.border)
                block("Cool down", steps: workout.cooldown, number: "03")
                Label(equipmentText, systemImage: "dumbbell")
                    .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }.padding(.top, 20)
        } label: {
            HStack(spacing: 12) {
                SymbolTile(symbol: "list.bullet.rectangle")
                VStack(alignment: .leading, spacing: 5) {
                    Text("Session breakdown").font(.headline).foregroundStyle(TrainingTheme.primary)
                    Text("\(workout.expandedSteps.count) steps · Warm-up to cool down")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }
            }
        }
        .trainingPanel()
        .sheet(item: $guide) { ExerciseGuideView(exercise: $0) }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.9), value: expanded)
    }
    private var equipmentText: String {
        workout.equipment.isEmpty ? "No equipment needed" : workout.equipment.map(\.title).joined(separator: " · ")
    }
    private func block(_ title: String, steps: [WorkoutStep], number: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(number).font(.caption.monospaced().weight(.semibold)).foregroundStyle(TrainingTheme.mint)
                Text(title).font(.headline)
            }
            ForEach(steps) { step in
                Button { guide = step.exercise } label: {
                    HStack(spacing: 12) {
                        ExerciseDemoThumbnail(exercise: step.exercise)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(step.title).font(.body.weight(.medium)).foregroundStyle(TrainingTheme.primary)
                            target(step)
                            if let original = step.substitutionFor {
                                Text("Training alternative to \(original.lowercased())")
                                    .font(.caption).foregroundStyle(TrainingTheme.secondary)
                            }
                            Text("See how to move").font(.caption.weight(.semibold)).foregroundStyle(TrainingTheme.accent)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right").foregroundStyle(TrainingTheme.accent)
                    }
                }.buttonStyle(.plain)
                .accessibilityLabel("\(step.title), \(step.targetText(units: units)). See how to move.")
            }
        }
    }
    private func target(_ step: WorkoutStep) -> some View {
        Text(step.targetText(units: units)).font(.subheadline.monospacedDigit()).foregroundStyle(TrainingTheme.secondary)
    }
}
