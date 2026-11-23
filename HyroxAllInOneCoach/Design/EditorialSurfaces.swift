import SwiftUI

/// Soft diagonal ribbons unify the welcome, daily workout and membership heroes.
struct TrainingAurora: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                TrainingTheme.heroBase
                RadialGradient(colors: [TrainingTheme.glowBlue, .clear],
                               center: .topTrailing, startRadius: 0, endRadius: width * 0.95)
                ribbons(width: width, height: height)
                    .offset(x: settled || reduceMotion ? 0 : 22, y: settled || reduceMotion ? 0 : -14)
                LinearGradient(colors: [TrainingTheme.heroBase.opacity(0.8), .clear],
                               startPoint: .leading, endPoint: .trailing)
                LinearGradient(stops: [.init(color: .clear, location: 0),
                                       .init(color: TrainingTheme.heroBase.opacity(0.92), location: 0.65),
                                       .init(color: TrainingTheme.heroBase, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }.clipped()
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 1.1)) { settled = true }
        }
    }
    private func ribbons(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ribbon(colors: [TrainingTheme.glowBlue, TrainingTheme.lavender.opacity(0.65)], width: width)
                .position(x: width * 0.7, y: height * 0.18)
            ribbon(colors: [TrainingTheme.lavender.opacity(0.7), TrainingTheme.glowViolet], width: width)
                .position(x: width * 0.95, y: height * 0.35)
            ribbon(colors: [TrainingTheme.glowViolet, TrainingTheme.glowBlue.opacity(0.75)], width: width)
                .position(x: width * 0.95, y: height * 0.02)
        }
    }
    private func ribbon(colors: [Color], width: CGFloat) -> some View {
        Capsule().fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .frame(width: width * 1.5, height: 75).rotationEffect(.degrees(-24))
            .blur(radius: 4)
    }
}

struct TrainingBackdrop: View {
    var body: some View {
        TrainingTheme.background
            .overlay(alignment: .topLeading) {
                RadialGradient(colors: [TrainingTheme.glowViolet.opacity(0.35), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 440)
            }
            .overlay(alignment: .topTrailing) {
                RadialGradient(colors: [TrainingTheme.glowBlue.opacity(0.25), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 360)
            }
            .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct HybridBrand: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(TrainingTheme.actionGradient)
                HStack(spacing: 3) {
                    Capsule().fill(.white.opacity(0.7)).frame(width: 5, height: 15)
                    Capsule().fill(.white).frame(width: 5, height: 23)
                    Capsule().fill(.white.opacity(0.7)).frame(width: 5, height: 15)
                }.rotationEffect(.degrees(22))
            }.frame(width: 38, height: 38).accessibilityHidden(true)
            Text("HYBRID").font(.headline.weight(.bold)).tracking(1.5)
            Text("TRAINING").font(.caption2.weight(.medium)).tracking(1)
                .foregroundStyle(TrainingTheme.secondary)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Hybrid Trainer")
    }
}

struct TrainingMetricWell: View {
    let value: String
    let label: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(TrainingTheme.mint)
                .accessibilityHidden(true)
            Text(value).font(.headline.monospacedDigit()).fixedSize(horizontal: false, vertical: true)
            Text(label).font(.caption).foregroundStyle(TrainingTheme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(13)
        .background(TrainingTheme.inset, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(TrainingTheme.border.opacity(0.7)))
        .accessibilityElement(children: .combine)
    }
}

struct TrainingCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct TrainingQuickActions: View {
    let library: () -> Void
    let history: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            action("Workout library", detail: "Find your rhythm", symbol: "square.grid.2x2", open: library)
            action("Your history", detail: "Every effort counts", symbol: "clock.arrow.circlepath", open: history)
        }
    }
    private func action(_ title: String, detail: String, symbol: String, open: @escaping () -> Void) -> some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbol).font(.title3).foregroundStyle(TrainingTheme.mint)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(TrainingTheme.secondary)
                }.accessibilityHidden(true)
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(TrainingTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).trainingPanel(padding: 16)
        }
        .buttonStyle(TrainingCardButtonStyle()).accessibilityElement(children: .combine)
    }
}
