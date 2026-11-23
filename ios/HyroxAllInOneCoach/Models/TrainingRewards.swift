import Foundation

enum TrainingGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case feelFitter, buildRoutine, raceReady
    var id: String { rawValue }
    var title: String {
        switch self {
        case .feelFitter: "Feel stronger & fitter"
        case .buildRoutine: "Build a steady routine"
        case .raceReady: "Work toward a hybrid race"
        }
    }
    var detail: String {
        switch self {
        case .feelFitter: "Move well, build confidence and enjoy the process."
        case .buildRoutine: "Make room for training without making it a chore."
        case .raceReady: "Practice the rhythm of running and strength."
        }
    }
}

struct TrainingJourney: Codable, Equatable, Sendable {
    var goal: TrainingGoal = .feelFitter
    var weeklyDays = 3
    var rewardsEnabled = true
}

struct TrainingBadge: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let current: Int
    let target: Int
    var earned: Bool { current >= target }
    var progress: Double { min(1, Double(current) / Double(target)) }
}

struct TrainingRewards {
    let sessions: [SessionRecord]
    var qualifying: [SessionRecord] { sessions.filter(\.qualifiesForProgress) }
    static func points(for record: SessionRecord) -> Int {
        // Rewards effort equally at every level, not speed, load or extra intensity.
        record.qualifiesForProgress ? 50 + min(50, record.completedCount * 5) : 0
    }
    var totalXP: Int { qualifying.reduce(0) { $0 + Self.points(for: $1) } }
    var level: Int { totalXP / 250 + 1 }
    var levelXP: Int { totalXP % 250 }
    var nextLevelXP: Int { 250 - levelXP }
    var levelTitle: String {
        switch level {
        case 1: "Foundation"
        case 2: "Momentum"
        case 3: "Finding your rhythm"
        case 4: "Growing stronger"
        default: "Steady progress"
        }
    }
    var badges: [TrainingBadge] {
        let variety = Set(qualifying.map { $0.workout.family }).count
        let recovery = qualifying.filter { $0.workout.family == .easy }.count
        let full = qualifying.filter { !$0.endedEarly && $0.completedCount == $0.workout.expandedSteps.count }.count
        return [
            TrainingBadge(id: "first", title: "First step", detail: "Save your first session with a completed step.",
                          symbol: "sparkles", current: qualifying.count, target: 1),
            TrainingBadge(id: "five", title: "Building momentum", detail: "Save 5 training sessions, at any pace.",
                          symbol: "bolt.fill", current: qualifying.count, target: 5),
            TrainingBadge(id: "recovery", title: "Recovery matters", detail: "Save a Move & recover session with a completed step.",
                          symbol: "leaf.fill", current: recovery, target: 1),
            TrainingBadge(id: "variety", title: "Well rounded", detail: "Try 3 different workout types.",
                          symbol: "circle.hexagongrid.fill", current: variety, target: 3),
            TrainingBadge(id: "full", title: "Start to finish", detail: "Complete every step of a session, including your cool down.",
                          symbol: "checkmark.seal.fill", current: full, target: 1),
            TrainingBadge(id: "ten", title: "In your stride", detail: "Save 10 sessions. No consecutive days required.",
                          symbol: "medal.fill", current: qualifying.count, target: 10)
        ]
    }
    func activeDaysThisWeek(now: Date = .now) -> Int {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        let dates = qualifying.filter { week.contains($0.startedAt) && $0.startedAt <= now }
            .map { calendar.startOfDay(for: $0.startedAt) }
        return Set(dates).count
    }
}

struct RewardReceipt: Identifiable {
    let id: UUID
    let points: Int
    let previousLevel: Int
    let rewards: TrainingRewards
    let newBadges: [TrainingBadge]
    var leveledUp: Bool { rewards.level > previousLevel }
}
