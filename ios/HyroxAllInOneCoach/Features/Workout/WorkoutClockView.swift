import SwiftUI

struct WorkoutClockView: View {
    let session: ActiveSession
    let current: ExpandedStep
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var clockSize = 88.0
    private var timed: Bool { current.step.targetKind == .time }
    private var accent: Color {
        session.isPaused ? TrainingTheme.blue : TrainingTheme.accent
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = session.stepElapsed(at: context.date)
            let displayed = timed ? max(0, current.step.target - elapsed) : elapsed
            VStack(spacing: 16) {
                dial(displayed: displayed, elapsed: elapsed)
                Text(timed ? "This step advances automatically." : "Tap Done when you’ve finished. Measured by you, not your phone.")
                    .font(.subheadline).foregroundStyle(TrainingTheme.secondary).multilineTextAlignment(.center)
                Label("Session \(TrainingFormat.clock(session.totalElapsed(at: context.date)))", systemImage: "clock")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(TrainingTheme.secondary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(TrainingTheme.inset, in: Capsule())
            }.frame(maxWidth: .infinity)
        }
    }
    private func dial(displayed: Double, elapsed: Double) -> some View {
        let fraction = timed ? max(0, min(1, displayed / max(1, current.step.target)))
            : Double(session.cursor) / Double(max(1, session.steps.count))
        return ZStack {
            Circle().fill(RadialGradient(colors: [accent.opacity(0.08), .clear], center: .center, startRadius: 0, endRadius: 150))
            DialTicks().stroke(TrainingTheme.secondary.opacity(0.3), lineWidth: 1).padding(1)
            Circle().stroke(TrainingTheme.border, lineWidth: 12).padding(15)
            Circle().trim(from: 0, to: fraction)
                .stroke(accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90)).padding(15)
                .animation(reduceMotion ? nil : .linear(duration: 0.5), value: fraction)
            readout(displayed: displayed)
        }
        .aspectRatio(1, contentMode: .fit).frame(maxWidth: 300)
    }
    private func readout(displayed: Double) -> some View {
        VStack(spacing: 12) {
            Image(systemName: session.isPaused ? "pause.fill" : current.step.exercise.symbol)
                .font(.title2).foregroundStyle(accent).accessibilityHidden(true)
            Eyebrow(text: session.isPaused ? "Paused" : (timed ? "Time remaining" : "Step elapsed"))
            Text(TrainingFormat.clock(displayed))
                .font(.custom("BarlowCondensed-Bold", size: clockSize).monospacedDigit())
                .minimumScaleFactor(0.35).lineLimit(1)
                .contentTransition(.numericText(countsDown: timed))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: Int(displayed))
                .accessibilityLabel(timed ? "Time remaining" : "Step elapsed")
                .accessibilityValue(TrainingFormat.clock(displayed))
            Text(session.isPaused ? "Take the time you need" : (timed ? "One step at a time" : "Ring: recorded session steps"))
                .font(.caption).foregroundStyle(TrainingTheme.secondary)
                .multilineTextAlignment(.center)
        }.padding(34)
    }
}

private struct DialTicks: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<60 {
            let angle = Double(index) / 60 * .pi * 2
            let length: CGFloat = index.isMultiple(of: 5) ? 7 : 3
            let outer = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            let inner = CGPoint(x: center.x + cos(angle) * (radius - length), y: center.y + sin(angle) * (radius - length))
            path.move(to: inner)
            path.addLine(to: outer)
        }
        return path
    }
}
