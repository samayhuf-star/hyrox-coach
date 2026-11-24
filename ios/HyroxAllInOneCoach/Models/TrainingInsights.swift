import Foundation

struct TrainingWeekVolume: Identifiable {
    let date: Date
    let sessions: Int
    let minutes: Double
    var id: Date { date }
}

struct TrainingMixItem: Identifiable {
    let family: WorkoutFamily
    let count: Int
    var id: String { family.id }
}

struct TrainingInsights {
    let records: [SessionRecord]
    let weeks: [TrainingWeekVolume]
    let mix: [TrainingMixItem]
    let trainingDays: Int
    let totalMinutes: Double
    let effortRecords: [SessionRecord]

    init(sessions: [SessionRecord], weekCount: Int, now: Date = .now) {
        let calendar = Calendar.current
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let firstWeek = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: thisWeek) ?? thisWeek
        let records = sessions.filter { $0.qualifiesForProgress && $0.startedAt >= firstWeek && $0.startedAt <= now }
            .sorted { $0.startedAt < $1.startedAt }
        self.records = records
        totalMinutes = records.reduce(0) { $0 + Self.minutes($1) }
        trainingDays = Set(records.map { calendar.startOfDay(for: $0.startedAt) }).count
        effortRecords = records.filter { $0.effort != nil }
        weeks = (0..<weekCount).compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: offset, to: firstWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let entries = records.filter { $0.startedAt >= start && $0.startedAt < end }
            return TrainingWeekVolume(date: start, sessions: entries.count, minutes: entries.reduce(0) { $0 + Self.minutes($1) })
        }
        mix = WorkoutFamily.allCases.compactMap { family in
            let count = records.filter { $0.workout.family == family }.count
            return count > 0 ? TrainingMixItem(family: family, count: count) : nil
        }
    }
    static func minutes(_ session: SessionRecord) -> Double {
        session.durationSeconds.isFinite ? max(0, session.durationSeconds / 60) : 0
    }
    static func effortValue(_ effort: SessionEffort?) -> Double {
        switch effort {
        case .easy: 1
        case .comfortable: 2
        case .challenging: 3
        case .veryHard: 4
        case nil: 0
        }
    }
}
