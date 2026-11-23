import SwiftUI

enum TrainingTab: Hashable { case today, plan }

/// What a planned or finished day is mostly about. Drives the colour of its square.
enum PlanDayKind: Sendable {
    case run, strength, raceStyle
    var title: String {
        switch self {
        case .run: return "Run"
        case .strength: return "Strength"
        case .raceStyle: return "Race-style"
        }
    }
    var color: Color {
        switch self {
        case .run: return TrainingTheme.accent
        case .strength: return TrainingTheme.mint
        case .raceStyle: return TrainingTheme.primary
        }
    }
    init(family: WorkoutFamily) {
        switch family {
        case .chain, .raceRehearsal: self = .raceStyle
        case .strength, .lowerBody, .stationMix, .rowCircuit, .skiCircuit, .custom: self = .strength
        default: self = .run
        }
    }
}

struct PlanDay: Identifiable {
    let id: Date
    let planned: PlanDayKind?
    let done: PlanDayKind?
    let isToday: Bool
}

struct PlanWeek: Identifiable {
    let id: Int
    let days: [PlanDay]
    var plannedCount: Int { days.filter { $0.planned != nil }.count }
    var doneCount: Int { days.filter { $0.done != nil }.count }
    var isCurrent: Bool { days.contains { $0.isToday } }
}

/// A six-week view of the weekly rhythm chosen in setup, filled in from saved sessions.
/// Nothing is stored: the block starts with the week of the first saved session in the
/// last five weeks, or with this week when there is none.
struct TrainingPlanBoard {
    let weeks: [PlanWeek]

    init(sessions: [SessionRecord], weeklyDays: Int, now: Date = Date(), calendar: Calendar = .current) {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let earliestAllowed = calendar.date(byAdding: .weekOfYear, value: -5, to: thisWeek) ?? thisWeek
        let qualifying = sessions.filter { $0.qualifiesForProgress && $0.startedAt >= earliestAllowed }
        let firstSession = qualifying.map(\.startedAt).min() ?? now
        let start = calendar.dateInterval(of: .weekOfYear, for: firstSession)?.start ?? thisWeek
        let offsets = Self.offsets(for: weeklyDays)
        let rotation: [PlanDayKind] = [.run, .strength, .raceStyle]
        var built: [PlanWeek] = []
        var slot = 0
        for week in 0..<6 {
            var days: [PlanDay] = []
            for offset in 0..<7 {
                let date = calendar.date(byAdding: .day, value: week * 7 + offset, to: start) ?? start
                var planned: PlanDayKind?
                if offsets.contains(offset) {
                    planned = rotation[slot % rotation.count]
                    slot += 1
                }
                let finished = qualifying.first { calendar.isDate($0.startedAt, inSameDayAs: date) }
                let done = finished.map { PlanDayKind(family: $0.workout.family) }
                days.append(PlanDay(id: date, planned: planned, done: done, isToday: calendar.isDate(date, inSameDayAs: now)))
            }
            built.append(PlanWeek(id: week + 1, days: days))
        }
        weeks = built
    }
    var current: PlanWeek? { weeks.first { $0.isCurrent } }

    static func offsets(for weeklyDays: Int) -> Set<Int> {
        switch weeklyDays {
        case ...1: return [2]
        case 2: return [1, 4]
        case 3: return [0, 2, 5]
        default: return [0, 2, 3, 5]
        }
    }
}

struct TrainingPlanView: View {
    let repository: TrainingRepository
    let chooseWorkout: () -> Void
    private var journey: TrainingJourney { repository.state.journey ?? TrainingJourney() }
    private var board: TrainingPlanBoard {
        TrainingPlanBoard(sessions: repository.sessions, weeklyDays: journey.weeklyDays)
    }
    var body: some View {
        let plan = self.board
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Your rhythm · 6 weeks", color: TrainingTheme.accent)
                Text("Your plan").font(.trainingDisplay()).textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
            }
            PlanGrid(board: plan)
            if let week = plan.current { thisWeek(week) }
            Button(action: chooseWorkout) {
                Label("Choose a session", systemImage: "square.grid.2x2")
            }
            .buttonStyle(TrainingButtonStyle(prominent: false))
            Text("A flexible aim, not a streak. Planned days are suggestions from the \(journey.weeklyDays) training days a week you chose; any saved session fills its day.")
                .font(.footnote).foregroundStyle(TrainingTheme.secondary)
        }
    }
    private func thisWeek(_ week: PlanWeek) -> some View {
        let left = max(0, week.plannedCount - week.doneCount)
        return HStack(spacing: 14) {
            Text("\(week.doneCount)/\(week.plannedCount)")
                .font(.trainingDisplay(.title2)).monospacedDigit()
                .frame(width: 64, height: 64)
                .overlay(Circle().strokeBorder(TrainingTheme.accent, lineWidth: 3))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("This week").font(.headline)
                Text(left == 0 ? "Weekly aim reached. Rest counts too." : "\(left) session\(left == 1 ? "" : "s") to go")
                    .font(.subheadline).foregroundStyle(TrainingTheme.mint)
            }
            Spacer(minLength: 0)
        }
        .trainingPanel(padding: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week: \(week.doneCount) of \(week.plannedCount) sessions done")
    }
}

private struct PlanGrid: View {
    let board: TrainingPlanBoard
    private let letters = ["M", "T", "W", "T", "F", "S", "S"]
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Text("").frame(width: 28)
                ForEach(Array(headerLetters.enumerated()), id: \.offset) { item in
                    Text(item.element).font(.caption2.weight(.bold)).foregroundStyle(TrainingTheme.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            ForEach(board.weeks) { week in
                HStack(spacing: 7) {
                    Text("W\(week.id)").font(.caption.weight(.bold)).foregroundStyle(TrainingTheme.secondary)
                        .frame(width: 28, alignment: .leading)
                    ForEach(week.days) { day in PlanCell(day: day) }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Week \(week.id): \(week.doneCount) of \(week.plannedCount) sessions done")
            }
            HStack(spacing: 16) {
                legend(.run)
                legend(.strength)
                legend(.raceStyle)
            }
            .padding(.top, 8)
        }
        .trainingPanel(padding: 16)
    }
    /// Weekday initials starting from the calendar's first weekday.
    private var headerLetters: [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        guard symbols.count == 7 else { return letters }
        return (0..<7).map { symbols[($0 + first) % 7] }
    }
    private func legend(_ kind: PlanDayKind) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(kind.color).frame(width: 12, height: 12)
            Text(kind.title).font(.caption).foregroundStyle(TrainingTheme.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PlanCell: View {
    let day: PlanDay
    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background { fill }
            .overlay { if day.isToday { RoundedRectangle(cornerRadius: 11).strokeBorder(TrainingTheme.primary, lineWidth: 2).padding(-4) } }
    }
    @ViewBuilder private var fill: some View {
        let shape = RoundedRectangle(cornerRadius: 9)
        if let done = day.done {
            shape.fill(done.color)
        } else if let planned = day.planned {
            shape.fill(TrainingTheme.inset).overlay(shape.strokeBorder(planned.color, lineWidth: 1.5))
        } else {
            shape.strokeBorder(TrainingTheme.border, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
    }
}

/// Floating tab bar. Today and Plan switch the main screen; Coach and Progress open their own screens.
struct TrainingTabBar: View {
    @Binding var selection: TrainingTab
    let coach: () -> Void
    let progress: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            item("Today", symbol: "house", selected: selection == .today) { selection = .today }
            item("Plan", symbol: "calendar", selected: selection == .plan) { selection = .plan }
            item("Coach", symbol: "bubble.left", selected: false, action: coach)
            item("Progress", symbol: "chart.bar", selected: false, action: progress)
        }
        .padding(6)
        .background(TrainingTheme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(TrainingTheme.border))
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
        .frame(maxWidth: 640).frame(maxWidth: .infinity)
        .background(TrainingTheme.background)
    }
    private func item(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.body.weight(.semibold))
                Text(title).font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(selected ? TrainingTheme.primary : TrainingTheme.secondary)
            .background(selected ? TrainingTheme.border : Color.clear, in: Capsule())
        }
        .buttonStyle(TrainingCardButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
