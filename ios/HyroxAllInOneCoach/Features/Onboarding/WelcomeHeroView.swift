import SwiftUI

struct WelcomeHeroView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 58.0
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            lanes.trainingReveal()
            cover
            Text("A training plan that mixes running and strength the way a hybrid race does. Built around your week in about a minute.")
                .font(.body).foregroundStyle(TrainingTheme.secondary)
                .trainingReveal(delay: 0.18)
        }
    }
    /// Alternating run and strength bars: the rhythm of a hybrid session.
    private var lanes: some View {
        VStack(alignment: .leading, spacing: 8) {
            lane("RUN", width: 0.88, color: TrainingTheme.accent)
            lane("STRENGTH", width: 0.68, color: TrainingTheme.mint)
            lane("RUN", width: 0.80, color: TrainingTheme.accent)
            lane("STRENGTH", width: 0.54, color: TrainingTheme.mint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
    private func lane(_ text: String, width: CGFloat, color: Color) -> some View {
        Text(text).font(.trainingDisplay(.title3)).tracking(1)
            .foregroundStyle(TrainingTheme.onAccent)
            .padding(.leading, 14).frame(height: 46)
            .containerRelativeFrame(.horizontal, alignment: .leading) { length, _ in length * width }
            .background(color, in: RoundedRectangle(cornerRadius: 8))
    }
    private var cover: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: "Hybrid Trainer", color: TrainingTheme.accent).padding(.top, typeSize.isAccessibilitySize ? 8 : 28)
            Text("Run strong.\nLift fast.\nRace ready.")
                .font(.custom("BarlowCondensed-Bold", size: headlineSize)).textCase(.uppercase)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
        .trainingReveal(delay: 0.1)
    }
}

struct TrainingBlueprintCard: View {
    let preferences: AthletePreferences
    let journey: TrainingJourney
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Eyebrow(text: "Your training blueprint", color: TrainingTheme.mint)
                Spacer()
                Image(systemName: "checkmark.seal.fill").foregroundStyle(TrainingTheme.mint).accessibilityHidden(true)
            }
            Text(journey.goal.title).font(.title2.weight(.bold))
            metrics
            HStack(spacing: 12) {
                Image(systemName: "calendar").foregroundStyle(TrainingTheme.mint).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(journey.weeklyDays) days. Room to recover.").font(.headline)
                    Text("A flexible aim, never a streak to protect.").font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }
            }
        }.trainingPanel().trainingReveal(delay: 0.1)
    }
    private var metrics: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            TrainingMetricWell(value: preferences.level.title, label: "Starting level", symbol: "chart.bar")
            TrainingMetricWell(value: "\(preferences.timeBudget) min", label: "Time available", symbol: "clock")
        }
    }
}
