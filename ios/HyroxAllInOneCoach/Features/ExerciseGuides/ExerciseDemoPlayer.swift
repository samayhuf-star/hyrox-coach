import SwiftUI

struct ExerciseDemoPlayer: View {
    let exercise: Exercise
    var autoplay = true
    var expand: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var phase = 0.0
    @State private var reference: Date?
    @State private var secondsPerPose = 0.75
    @State private var playing = true
    @State private var slow = false
    @State private var visible = false

    private var demo: MovementDemo { exercise.demo }
    private var clipURL: URL? { Bundle.main.url(forResource: demo.asset, withExtension: "mp4") }
    private var looping: Bool {
        visible && playing && autoplay && !reduceMotion && !demo.still && scenePhase == .active
    }
    private var manual: Bool { !playing || reduceMotion || !autoplay || demo.still }
    private var pose: Int { Int(phase) % demo.poses.count }
    private var status: String {
        if demo.still { return "REST GUIDE" }
        if reduceMotion { return "MOVEMENT GUIDE" }
        return playing && autoplay ? "LOOPING DEMO" : "PAUSED"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stage
            VStack(alignment: .leading, spacing: 12) {
                guidance
                controls
                Text(reduceMotion ? "Reduce Motion is on · use the arrows to explore the positions." : "AI-generated movement guide · 3 seconds per position")
                    .font(.caption).foregroundStyle(TrainingTheme.secondary)
            }.padding(16)
        }
        .background(TrainingTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(TrainingTheme.border))
        .onAppear { secondsPerPose = interval; visible = true }
        .onDisappear { visible = false }
        .onChange(of: looping) { _, active in updateClock(active: active) }
        .onChange(of: slow) { _, _ in changeSpeed() }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { freeze(); phase = Double(pose) }
        }
        .onChange(of: exercise.id) { _, _ in reset() }
    }

    private var stage: some View {
        Group {
            if let clip = clipURL, looping {
                ExerciseClipView(url: clip, active: true, rate: slow ? 0.55 : 1)
                    .aspectRatio(1, contentMode: .fit)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !looping)) { context in
                    ExerciseLoopView(asset: demo.asset, frames: demo.frames, position: position(at: context.date))
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Text(status)
                .font(.caption.weight(.bold)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.black.opacity(0.65), in: Capsule()).padding(14)
        }
        .overlay(alignment: .topTrailing) {
            if let expand {
                Button(action: expand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.body.weight(.semibold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).background(.black.opacity(0.65), in: Circle())
                }.padding(10).accessibilityLabel("Open full exercise guide and pause workout")
            }
        }
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(manual ? demo.poses[pose].title : "Move with control")
                .font(.headline).foregroundStyle(TrainingTheme.primary)
            Text(manual ? demo.poses[pose].cue : exercise.cues)
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            playback
            if manual { manualControls }
            Spacer(minLength: 0)
            speed
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var playback: some View {
        if !reduceMotion && autoplay && !demo.still {
            Button {
                freeze()
                playing.toggle()
            } label: {
                Label(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).frame(minHeight: 44)
            }
            .foregroundStyle(TrainingTheme.accent)
            .background(TrainingTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel(playing ? "Pause demo only" : "Play demo only")
        }
    }

    private var manualControls: some View {
        HStack(spacing: 6) {
            Button { step(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel("Previous position")
            Button { step(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .accessibilityLabel("Next position")
        }
        .foregroundStyle(TrainingTheme.accent)
        .background(TrainingTheme.background, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private var speed: some View {
        if !reduceMotion && autoplay && !demo.still {
            Button(slow ? "Slow" : "1×") { slow.toggle() }
                .font(.subheadline.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(TrainingTheme.accent)
                .accessibilityLabel(slow ? "Slow demo, tap for normal speed" : "Normal speed, tap for slow demo")
        }
    }

    private var interval: Double { demo.interval * 0.75 * (slow ? 1.8 : 1) }

    private func position(at date: Date) -> Double {
        let elapsed = reference.map { max(0, date.timeIntervalSince($0)) } ?? 0
        return (phase + elapsed / secondsPerPose).truncatingRemainder(dividingBy: Double(demo.frames.count))
    }

    private func freeze(at date: Date = Date()) {
        phase = position(at: date)
        reference = nil
    }

    private func updateClock(active: Bool) {
        let now = Date()
        freeze(at: now)
        if active { reference = now }
    }

    private func changeSpeed() {
        let now = Date()
        freeze(at: now)
        secondsPerPose = interval
        if looping { reference = now }
    }

    private func step(_ direction: Int) {
        freeze()
        playing = false
        let count = demo.poses.count
        phase = Double((pose + direction + count) % count)
    }

    private func reset() {
        reference = nil
        phase = 0
        playing = true
        secondsPerPose = interval
        if looping { reference = Date() }
    }
}
