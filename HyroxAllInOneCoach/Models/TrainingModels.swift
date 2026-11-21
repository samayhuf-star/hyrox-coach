import Foundation

enum AthleteLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner, regular, experienced
    var id: String { rawValue }
    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .regular: "Regular"
        case .experienced: "Experienced"
        }
    }
    var detail: String {
        switch self {
        case .beginner: "A gentle starting point. Walking and lighter targets are welcome."
        case .regular: "For people already training a few times a week."
        case .experienced: "Longer work blocks for confident hybrid athletes."
        }
    }
}

enum UnitSystem: String, Codable, CaseIterable, Identifiable, Sendable {
    case metric, imperial
    var id: String { rawValue }
    var title: String { self == .metric ? "Metric · m / kg" : "Imperial · yd / lb" }
    var distanceUnit: String { self == .metric ? "m" : "yd" }
    var loadUnit: String { self == .metric ? "kg" : "lb" }
    func distanceValue(_ meters: Double) -> Double { self == .metric ? meters : meters / 0.9144 }
    func meters(_ value: Double) -> Double { self == .metric ? value : value * 0.9144 }
    func loadValue(_ kg: Double) -> Double { self == .metric ? kg : kg * 2.20462 }
    func kilograms(_ value: Double) -> Double { self == .metric ? value : value / 2.20462 }
}

enum Equipment: String, Codable, CaseIterable, Identifiable, Sendable {
    case runningSpace, kettlebell, rower, skiErg, sandbag, wallBall, sled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .runningSpace: "Running space"
        case .kettlebell: "Dumbbells / kettlebells"
        case .rower: "Rowing machine"
        case .skiErg: "SkiErg"
        case .sandbag: "Sandbag"
        case .wallBall: "Wall ball & target"
        case .sled: "Sled & track"
        }
    }
}

struct AthletePreferences: Codable, Equatable, Sendable {
    var level: AthleteLevel = .beginner
    var timeBudget = 25
    var equipment: Set<Equipment> = [.runningSpace, .kettlebell]
    var units: UnitSystem = .metric
    var haptics = true
    var sound = false
}

enum WorkoutFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case engine, introduction, strength, easy, custom
    case endurance, runCarry, lowerBody, bodyweight, rowCircuit, skiCircuit, stationMix, runLunge
    static var starters: [WorkoutFamily] {
        [.engine, .introduction, .strength, .easy, .endurance, .runCarry,
         .lowerBody, .bodyweight, .rowCircuit, .skiCircuit, .stationMix, .runLunge]
    }
    var id: String { rawValue }
    var title: String {
        switch self {
        case .engine: "Build your engine"
        case .introduction: "Your first hybrid session"
        case .strength: "Stronger at every station"
        case .easy: "Move & recover"
        case .custom: "My custom session"
        case .endurance: "Steady engine intervals"
        case .runCarry: "Run, carry, repeat"
        case .lowerBody: "Legs with control"
        case .bodyweight: "No-kit hybrid circuit"
        case .rowCircuit: "Row & reset"
        case .skiCircuit: "Ski & stride"
        case .stationMix: "Station sampler"
        case .runLunge: "Run & lunge"
        }
    }
    var category: String {
        switch self {
        case .engine, .runCarry, .runLunge: "Run + strength"
        case .introduction: "Getting started"
        case .strength, .stationMix: "Station practice"
        case .easy: "Lighter day"
        case .custom: "Custom session"
        case .endurance: "Steady endurance"
        case .lowerBody: "Lower-body strength"
        case .bodyweight: "No equipment"
        case .rowCircuit: "Row + strength"
        case .skiCircuit: "Ski + run"
        }
    }
    var purpose: String {
        switch self {
        case .engine: "Practice moving from running to strength, at a pace you can sustain."
        case .introduction: "Get comfortable with the rhythm of hybrid training. One step at a time."
        case .strength: "Build controlled, repeatable strength for carrying, squatting and lunging."
        case .easy: "Keep moving gently. Leave feeling fresher, not exhausted."
        case .custom: "A session you’ve built for the way you like to train."
        case .endurance: "Alternate relaxed running with breathing breaks. Walking is always welcome."
        case .runCarry: "Move from an easy run to a steady carry. Focus on tall posture, not speed."
        case .lowerBody: "Practice squats and lunges with control. Use a comfortable range and take your rest."
        case .bodyweight: "March, squat, walk and lunge without equipment. Find a rhythm that feels manageable."
        case .rowCircuit: "Pair steady rowing with controlled squats, then let your breathing settle."
        case .skiCircuit: "Alternate SkiErg practice and an easy run. Keep both efforts steady and repeatable."
        case .stationMix: "Explore rowing, SkiErg, carries and wall balls with light targets and plenty of rest."
        case .runLunge: "Pair an easy run with controlled lunges. Keep your steps steady and rest between rounds."
        }
    }
    var symbol: String {
        switch self {
        case .engine, .endurance, .runCarry, .runLunge: "figure.run"
        case .introduction, .bodyweight: "figure.walk"
        case .strength, .lowerBody, .stationMix: "dumbbell.fill"
        case .easy: "leaf.fill"
        case .custom: "slider.horizontal.3"
        case .rowCircuit: "figure.rower"
        case .skiCircuit: "figure.skiing.crosscountry"
        }
    }
}

enum TargetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case time, distance, repetitions
    var id: String { rawValue }
    var title: String {
        switch self {
        case .time: "Time"
        case .distance: "Distance"
        case .repetitions: "Repetitions"
        }
    }
}

enum TrainingPhase: String, Codable, Sendable {
    case warmup, work, rest, cooldown
    var title: String {
        switch self {
        case .warmup: "Warm-up"
        case .work: "Main work"
        case .rest: "Rest"
        case .cooldown: "Cool down"
        }
    }
}

struct WorkoutStep: Codable, Equatable, Identifiable, Sendable {
    var id = UUID().uuidString
    var exerciseID: String
    var targetKind: TargetKind
    var target: Double
    var loadKg: Double = 0
    var estimatedSeconds: Double
    var substitutionFor: String?
    var exercise: Exercise { ExerciseCatalog.find(exerciseID) }
    var title: String { exercise.title }
    var isRest: Bool { exerciseID == "rest" }
    func targetText(units: UnitSystem) -> String {
        let value: String
        switch targetKind {
        case .time: value = TrainingFormat.duration(target)
        case .distance: value = "\(TrainingFormat.number(units.distanceValue(target))) \(units.distanceUnit)"
        case .repetitions: value = "\(TrainingFormat.number(target)) reps"
        }
        return loadKg > 0 ? "\(value) · \(TrainingFormat.number(units.loadValue(loadKg))) \(units.loadUnit)" : value
    }
}

struct WorkoutDefinition: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var family: WorkoutFamily
    var title: String
    var purpose: String
    var level: AthleteLevel
    var timeBudget: Int
    var rounds: Int
    var warmup: [WorkoutStep]
    var main: [WorkoutStep]
    var cooldown: [WorkoutStep]
    var estimatedMinutes: Int {
        let seconds = warmup.reduce(0) { $0 + $1.estimatedSeconds }
            + main.reduce(0) { $0 + $1.estimatedSeconds } * Double(rounds)
            + cooldown.reduce(0) { $0 + $1.estimatedSeconds }
        return max(1, Int(ceil(seconds / 60)))
    }
    var equipment: [Equipment] {
        let items = (warmup + main + cooldown).compactMap { $0.exercise.equipment }
        return Equipment.allCases.filter { Set(items).contains($0) }
    }
    var expandedSteps: [ExpandedStep] {
        var steps = warmup.map { ExpandedStep(id: "warm-\($0.id)", step: $0, phase: .warmup, round: nil) }
        for round in 1...max(1, rounds) {
            steps += main.map {
                ExpandedStep(id: "round-\(round)-\($0.id)", step: $0, phase: $0.isRest ? .rest : .work, round: round)
            }
        }
        steps += cooldown.map { ExpandedStep(id: "cool-\($0.id)", step: $0, phase: .cooldown, round: nil) }
        return steps
    }
}

struct ExpandedStep: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var step: WorkoutStep
    var phase: TrainingPhase
    var round: Int?
}

enum StepStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case completed, skipped
    var id: String { rawValue }
    var title: String { self == .completed ? "Completed" : "Skipped" }
}

struct StepResult: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var status: StepStatus
    var elapsedSeconds: Double
    var actualTarget: Double?
    var actualLoadKg: Double?
}

enum SessionEffort: String, Codable, CaseIterable, Identifiable, Sendable {
    case easy, comfortable, challenging, veryHard
    var id: String { rawValue }
    var title: String {
        switch self {
        case .easy: "Easy"
        case .comfortable: "Comfortable"
        case .challenging: "Challenging"
        case .veryHard: "Very hard"
        }
    }
}

struct SessionRecord: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var workout: WorkoutDefinition
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Double
    var results: [StepResult]
    var endedEarly: Bool
    var effort: SessionEffort?
    var note: String
    var completedCount: Int { results.filter { $0.status == .completed }.count }
    var skippedCount: Int { results.filter { $0.status == .skipped }.count }
    var qualifiesForProgress: Bool { completedCount > 0 }
}

struct ActiveSession: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var workout: WorkoutDefinition
    var startedAt: Date
    var cursor = 0
    var results: [StepResult] = []
    var stepAccumulatedSeconds: Double = 0
    var totalAccumulatedSeconds: Double = 0
    var runningSince: Date?
    var actualTarget: Double?
    var actualLoadKg: Double?
    var summary: SessionRecord?
    var steps: [ExpandedStep] { workout.expandedSteps }
    var current: ExpandedStep? { steps.indices.contains(cursor) ? steps[cursor] : nil }
    var isPaused: Bool { runningSince == nil }
    func delta(at now: Date) -> Double { runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0 }
    func stepElapsed(at now: Date) -> Double { stepAccumulatedSeconds + delta(at: now) }
    func totalElapsed(at now: Date) -> Double { totalAccumulatedSeconds + delta(at: now) }
    mutating func settle(at now: Date) {
        let interval = delta(at: now)
        stepAccumulatedSeconds += interval
        totalAccumulatedSeconds += interval
        if runningSince != nil { runningSince = now }
    }
}

struct TrainingSnapshot: Codable, Equatable, Sendable {
    var version = 1
    var preferences = AthletePreferences()
    var workouts: [WorkoutDefinition] = []
    var selectedWorkoutID = WorkoutFamily.engine.rawValue
    var sessions: [SessionRecord] = []
    var active: ActiveSession?
    // Optional so version-1 snapshots saved before onboarding continue to decode.
    var journey: TrainingJourney?
    // Remaining starter IDs in a shuffled cycle; old snapshots have no rotation yet.
    var workoutRotation: [String]?
}

enum TrainingFormat {
    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        if total >= 3600 { return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60) }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
    static func duration(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded()))
        return value % 60 == 0 && value >= 60 ? "\(value / 60) min" : "\(value) sec"
    }
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
