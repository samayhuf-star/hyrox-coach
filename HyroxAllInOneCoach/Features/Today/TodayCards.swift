import SwiftUI

struct TodayWorkoutCard: View {
    let workout: WorkoutDefinition
    let active: ActiveSession?
    let units: UnitSystem
    let adjust: () -> Void
    let change: () -> Void
    let shuffle: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    private var displayed: WorkoutDefinition { active?.workout ?? workout }
    var body: some View {
        VStack(spacing: 0) {
            cover
            VStack(alignment: .leading, spacing: 12) {
                metrics
                WorkoutPhaseStrip(workout: displayed)
                workoutActions
            }.padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 8)
        }
        .background(TrainingTheme.surface, in: RoundedRectangle(cornerRadius: 26))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(TrainingTheme.border))
        .shadow(color: TrainingTheme.shadow.opacity(0.08), radius: 22, y: 8)
    }
    private var workoutActions: some View {
        VStack(spacing: 4) {
            if active == nil {
                Button(action: shuffle) {
                    Label("Try another workout", systemImage: "shuffle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain).foregroundStyle(TrainingTheme.accent)
                .background(TrainingTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHint("Picks a different starter without changing your saved edits.")
            }
            Button(action: adjust) {
                Label("Adjust workout", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.plain).foregroundStyle(TrainingTheme.secondary)
        }
    }
    private var cover: some View {
        VStack(alignment: .leading, spacing: 35) {
            HStack {
                StatusPill(text: active == nil ? "Ready when you are" : "Session in progress", symbol: active == nil ? "bolt.fill" : "pause.circle")
                    .background(TrainingTheme.surface.opacity(0.9), in: Capsule())
                Spacer(minLength: 6)
                Button("Change", action: change)
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    .padding(.horizontal, 12).foregroundStyle(TrainingTheme.accent)
                    .background(TrainingTheme.surface.opacity(0.9), in: Capsule())
            }
            VStack(alignment: .leading, spacing: 9) {
                Eyebrow(text: displayed.family.category, color: TrainingTheme.mint)
                Text(displayed.title).font(.trainingDisplay()).textCase(.uppercase).tracking(-0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 165, alignment: .bottomLeading)
        .padding(20).background { TrainingAurora() }
    }
    private var metrics: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            metric("~\(displayed.estimatedMinutes) min", label: "Duration")
            metric("\(displayed.rounds) rounds", label: "Structure")
            metric(displayed.level.title, label: "Level")
        }
    }
    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(TrainingTheme.secondary)
            Text(value).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(TrainingTheme.inset, in: RoundedRectangle(cornerRadius: 13))
        .accessibilityElement(children: .combine)
    }
}

struct TodayNextAction: View {
    let workout: WorkoutDefinition
    let active: ActiveSession?
    let units: UnitSystem
    let action: () -> Void

    private var title: String {
        if active?.summary != nil { return "Review & save workout" }
        return active == nil ? "Start workout" : "Resume workout"
    }
    private var guidance: String {
        if active?.summary != nil { return "Check your session, then save it to history." }
        if let active, let step = active.current?.step {
            return "Continue at \(step.title) · \(step.targetText(units: units))"
        }
        if active != nil { return "Continue your session where you left off." }
        if let step = workout.expandedSteps.first?.step {
            return "Start with \(step.title) · \(step.targetText(units: units))"
        }
        return "Your guided session is ready when you are."
    }
    private var hint: String {
        if active?.summary != nil { return "Opens your completed session for review before saving." }
        return active == nil ? "Starts the selected workout and its first step timer."
            : "Opens your current workout. If paused, you can resume from there."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "Your next step", color: TrainingTheme.accent)
                Text(guidance).font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: action) {
                HStack(spacing: 12) {
                    Text(title).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: active?.summary != nil ? "checkmark.circle" : "arrow.right")
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(TrainingButtonStyle())
            .accessibilityHint(hint)
            .accessibilityIdentifier("today-primary-action")
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)
        .frame(maxWidth: 640).frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Rectangle().fill(TrainingTheme.border).frame(height: 1) }
    }
}

struct WorkoutPhaseStrip: View {
    let workout: WorkoutDefinition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let available = max(0, geometry.size.width - 8)
                HStack(spacing: 4) {
                    segment(count: workout.warmup.count, color: TrainingTheme.lavender, width: available)
                    segment(count: workout.main.count * workout.rounds, color: TrainingTheme.accent, width: available)
                    segment(count: workout.cooldown.count, color: TrainingTheme.blue, width: available)
                }
            }
            .frame(height: 5).scaleEffect(x: revealed || reduceMotion ? 1 : 0, anchor: .leading)
            HStack {
                Text("Warm-up")
                Spacer()
                Text("Work + rest")
                Spacer()
                Text("Cool down")
            }.font(.caption2.weight(.medium)).foregroundStyle(TrainingTheme.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(workout.warmup.count) warm-up steps, \(workout.main.count * workout.rounds) work and rest steps, \(workout.cooldown.count) cooldown steps")
        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7).delay(0.18)) { revealed = true } }
    }
    private func segment(count: Int, color: Color, width: CGFloat) -> some View {
        let total = max(1, workout.warmup.count + workout.main.count * workout.rounds + workout.cooldown.count)
        return color.clipShape(Capsule()).frame(width: width * CGFloat(count) / CGFloat(total))
    }
}

struct SessionRhythmView: View {
    var body: some View {
        HStack(spacing: 12) {
            Label("Move", systemImage: "figure.run")
            Image(systemName: "arrow.right")
            Label("Strength", systemImage: "dumbbell")
            Image(systemName: "arrow.right")
            Label("Recover", systemImage: "wind")
        }
        .font(.caption).foregroundStyle(TrainingTheme.mint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session rhythm: movement, strength, recovery")
    }
}

struct WeeklyProgressCard: View {
    let days: [TrainingDay]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    private var sessions: Int { days.reduce(0) { $0 + $1.count } }
    private var activeDays: Int { days.filter { $0.count > 0 }.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "This week")
                    Text("Find your rhythm.").font(.title3.weight(.bold))
                }
                Spacer()
                Text("\(sessions)").font(.largeTitle.weight(.bold).monospacedDigit())
                    .foregroundStyle(TrainingTheme.mint)
                    .accessibilityLabel("\(sessions) saved sessions this week")
            }
            HStack(alignment: .bottom, spacing: 9) {
                ForEach(days) { day in dayColumn(day) }
            }
            HStack(spacing: 8) {
                Circle().fill(TrainingTheme.mint).frame(width: 5, height: 5).accessibilityHidden(true)
                Text(sessions == 0 ? "A fresh week. Your first session is waiting." : "\(activeDays) active \(activeDays == 1 ? "day" : "days"). Recovery counts, too.")
                    .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }
        }
        .trainingPanel()
        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) { appeared = true } }
    }
    private func dayColumn(_ day: TrainingDay) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 9).fill(TrainingTheme.background.opacity(0.65))
                if day.count > 0 {
                    RoundedRectangle(cornerRadius: 9).fill(TrainingTheme.mint.gradient)
                        .frame(height: min(70, CGFloat(day.count) * 22 + 14))
                        .scaleEffect(y: appeared || reduceMotion ? 1 : 0, anchor: .bottom)
                }
                if day.isToday {
                    RoundedRectangle(cornerRadius: 9).strokeBorder(TrainingTheme.mint.opacity(0.65))
                }
            }.frame(height: 70)
            Text(day.date, format: .dateTime.weekday(.narrow))
                .font(.caption.weight(day.isToday ? .bold : .regular))
                .foregroundStyle(day.isToday ? TrainingTheme.primary : TrainingTheme.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide))), \(day.count) saved sessions\(day.isToday ? ", today" : "")")
    }
}
