import SwiftUI

struct PlusToolsCard: View {
    let isPlus: Bool
    let open: (PlusFeature) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeading(title: "Go beyond the everyday.")
                Spacer()
                Text("PLUS").font(.caption.weight(.bold)).tracking(1).foregroundStyle(TrainingTheme.mint)
            }
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            layout {
                tool(.builder, title: "Build your own", detail: "Your moves. Your rhythm.")
                tool(.insights, title: "See the bigger picture", detail: "Your effort, in context.")
            }
        }
    }
    private func tool(_ feature: PlusFeature, title: String, detail: String) -> some View {
        Button { open(feature) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: feature.symbol).font(.title2).foregroundStyle(TrainingTheme.mint)
                    Spacer()
                    Image(systemName: isPlus ? "arrow.up.right" : "lock").font(.caption).foregroundStyle(TrainingTheme.secondary)
                }.frame(minHeight: 32).accessibilityHidden(true)
                Text(title).font(.headline).foregroundStyle(TrainingTheme.primary)
                Text(detail).font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                Text(isPlus ? "Open tool →" : "Included with Plus")
                    .font(.caption.weight(.medium)).foregroundStyle(TrainingTheme.mint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).trainingPanel(padding: 16)
        }.buttonStyle(TrainingCardButtonStyle()).accessibilityElement(children: .combine)
    }
}

struct PlusFeatureView: View {
    @Environment(PlusPurchaseStore.self) private var store
    let repository: TrainingRepository
    let feature: PlusFeature
    var workout: WorkoutDefinition? = nil
    var body: some View {
        Group {
            if store.isPlus {
                switch feature {
                case .builder: CustomWorkoutBuilderView(repository: repository, workout: workout)
                case .insights: ProgressInsightsView(repository: repository)
                }
            } else { PlusPaywallView(focus: feature) }
        }
    }
}
