import SwiftUI

struct WelcomeHeroView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 42.0
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            cover
            Text("Running meets strength.\nProgress meets possibility.")
                .font(.title3.weight(.medium)).foregroundStyle(TrainingTheme.primary)
                .trainingReveal(delay: 0.12)
            HStack(spacing: 8) {
                tag("Your level", symbol: "chart.bar")
                tag("Your time", symbol: "clock")
                tag("Your pace", symbol: "heart")
            }
            .trainingReveal(delay: 0.18)
        }
    }
    private var cover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: "Strength × Endurance", color: TrainingTheme.mint)
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(TrainingTheme.mint).accessibilityHidden(true)
            }
            Spacer(minLength: 100)
            Text("A stronger you.").font(.system(size: headlineSize, weight: .bold)).tracking(-1.2)
                .fixedSize(horizontal: false, vertical: true)
            Text("At your pace.").font(.system(size: headlineSize, weight: .bold)).tracking(-1.2)
                .foregroundStyle(TrainingTheme.mint).fixedSize(horizontal: false, vertical: true)
            Text("WELCOME TO HYBRID TRAINING").font(.caption.weight(.semibold)).tracking(1.6)
                .padding(.top, 4)
        }
        .padding(24).frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 420 : 340, alignment: .leading)
        .background { TrainingAurora() }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(TrainingTheme.border))
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
        .trainingReveal()
    }
    private func tag(_ text: String, symbol: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).foregroundStyle(TrainingTheme.mint).accessibilityHidden(true)
            Text(text).foregroundStyle(TrainingTheme.secondary)
        }
        .font(.caption.weight(.medium)).frame(maxWidth: .infinity)
        .padding(.vertical, 13).background(TrainingTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
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
