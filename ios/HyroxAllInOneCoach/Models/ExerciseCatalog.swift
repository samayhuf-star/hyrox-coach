import Foundation

struct Exercise: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let symbol: String
    let equipment: Equipment?
    let cues: String
    let defaultKind: TargetKind
    let defaultTarget: Double
    let secondsPerUnit: Double
}

enum ExerciseCatalog {
    static let all: [Exercise] = [
        Exercise(id: "walk", title: "Brisk walk", symbol: "figure.walk", equipment: nil,
                 cues: "Walk tall with relaxed shoulders. Choose a pace where you can still talk comfortably.",
                 defaultKind: .time, defaultTarget: 180, secondsPerUnit: 1),
        Exercise(id: "run", title: "Easy run", symbol: "figure.run", equipment: .runningSpace,
                 cues: "Start easy. Keep your steps relaxed and your breathing steady. Walking is always an option.",
                 defaultKind: .distance, defaultTarget: 400, secondsPerUnit: 0.45),
        Exercise(id: "march", title: "March in place", symbol: "figure.walk", equipment: nil,
                 cues: "Stand tall and lift one knee at a time. Use a wall for balance if needed. Keep the pace comfortable.",
                 defaultKind: .time, defaultTarget: 90, secondsPerUnit: 1),
        Exercise(id: "squat", title: "Bodyweight squat", symbol: "figure.strengthtraining.functional", equipment: nil,
                 cues: "Feet comfortably apart. Sit back and down only as far as feels comfortable, then stand tall. Use a stable chair if needed.",
                 defaultKind: .repetitions, defaultTarget: 10, secondsPerUnit: 4),
        Exercise(id: "goblet", title: "Goblet squat", symbol: "dumbbell.fill", equipment: .kettlebell,
                 cues: "Hold one weight close to your chest. Keep your feet grounded. Lower with control, then stand. Choose a light, comfortable load.",
                 defaultKind: .repetitions, defaultTarget: 10, secondsPerUnit: 4),
        Exercise(id: "carry", title: "Farmer’s carry", symbol: "figure.strengthtraining.functional", equipment: .kettlebell,
                 cues: "Hold a weight in each hand and walk tall. Keep your shoulders relaxed and take steady steps. The load shown is per hand.",
                 defaultKind: .distance, defaultTarget: 80, secondsPerUnit: 1.1),
        Exercise(id: "lunge", title: "Reverse lunge", symbol: "figure.strengthtraining.functional", equipment: nil,
                 cues: "Step one foot back, bend both knees within a comfortable range, then return. Alternate legs. Count each lunge as one rep. Hold support if needed.",
                 defaultKind: .repetitions, defaultTarget: 10, secondsPerUnit: 5),
        Exercise(id: "sandbag", title: "Sandbag lunge", symbol: "figure.strengthtraining.functional", equipment: .sandbag,
                 cues: "Support the bag securely, step forward and lower with control. Alternate legs. Keep the load light enough to move steadily.",
                 defaultKind: .repetitions, defaultTarget: 10, secondsPerUnit: 5),
        Exercise(id: "row", title: "Row", symbol: "figure.rower", equipment: .rower,
                 cues: "Push with your legs, lean back slightly, then pull the handle. Return hands first, then bend your knees. Keep the effort steady.",
                 defaultKind: .distance, defaultTarget: 300, secondsPerUnit: 0.5),
        Exercise(id: "ski", title: "SkiErg", symbol: "figure.skiing.crosscountry", equipment: .skiErg,
                 cues: "Start tall with soft knees. Pull the handles down as you hinge at the hips. Return smoothly and repeat without rushing.",
                 defaultKind: .distance, defaultTarget: 300, secondsPerUnit: 0.5),
        Exercise(id: "wallball", title: "Wall ball", symbol: "figure.basketball", equipment: .wallBall,
                 cues: "Hold the ball at your chest, squat within a comfortable range, then stand and throw to your target. Catch softly. Pick a light ball and safe target.",
                 defaultKind: .repetitions, defaultTarget: 10, secondsPerUnit: 5),
        Exercise(id: "sled", title: "Sled push", symbol: "figure.strengthtraining.functional", equipment: .sled,
                 cues: "Keep your back neutral, brace gently and push with short, steady steps. Use a light sled and a clear track. Ask a coach if this is new.",
                 defaultKind: .distance, defaultTarget: 25, secondsPerUnit: 3),
        Exercise(id: "sledpull", title: "Sled pull", symbol: "figure.strengthtraining.functional", equipment: .sled,
                 cues: "Face the sled, sit your hips back and pull the rope hand over hand with a neutral back. Keep the rope clear of your feet. Use a light sled and ask a coach if this is new.",
                 defaultKind: .distance, defaultTarget: 25, secondsPerUnit: 3.5),
        Exercise(id: "burpee", title: "Burpee broad jump", symbol: "figure.jumprope", equipment: nil,
                 cues: "Hands down, chest to the floor, stand up, then jump forward with both feet and land softly. Step back and step up instead of jumping if you prefer. Small, steady jumps beat big ones.",
                 defaultKind: .distance, defaultTarget: 20, secondsPerUnit: 4.5),
        Exercise(id: "rest", title: "Rest & breathe", symbol: "pause.circle", equipment: nil,
                 cues: "Let your breathing settle. Walk slowly or stand comfortably. Pause the timer if you need a little more rest.",
                 defaultKind: .time, defaultTarget: 60, secondsPerUnit: 1),
        Exercise(id: "cooldown", title: "Easy walk & breathe", symbol: "figure.cooldown", equipment: nil,
                 cues: "Slow down to an easy walk. Relax your arms and breathe naturally. Finish feeling settled.",
                 defaultKind: .time, defaultTarget: 120, secondsPerUnit: 1)
    ]
    static func find(_ id: String) -> Exercise { all.first { $0.id == id } ?? all[0] }
    static func step(_ id: String, target: Double? = nil, load: Double = 0, substitution: String? = nil) -> WorkoutStep {
        let exercise = find(id)
        let quantity = target ?? exercise.defaultTarget
        return WorkoutStep(exerciseID: id, targetKind: exercise.defaultKind, target: quantity,
                           loadKg: load, estimatedSeconds: quantity * exercise.secondsPerUnit, substitutionFor: substitution)
    }
}

enum WorkoutFactory {
    static func make(_ family: WorkoutFamily, preferences: AthletePreferences) -> WorkoutDefinition {
        let level = preferences.level
        let factor = level == .beginner ? 1.0 : (level == .regular ? 1.3 : 1.7)
        let reps = (10 * factor).rounded()
        let load = level == .beginner ? 4.0 : (level == .regular ? 8.0 : 12.0)
        let available = preferences.equipment
        let run = available.contains(.runningSpace)
            ? ExerciseCatalog.step("run", target: (400 * factor).rounded())
            : ExerciseCatalog.step("march", target: tidy(180 * factor), substitution: "Easy run")
        let squat = available.contains(.kettlebell)
            ? ExerciseCatalog.step("goblet", target: reps, load: load)
            : ExerciseCatalog.step("squat", target: reps, substitution: "Goblet squat")
        let carry = available.contains(.kettlebell)
            ? ExerciseCatalog.step("carry", target: 80, load: load)
            : ExerciseCatalog.step("march", target: 75, substitution: "Farmer’s carry")
        let rest = ExerciseCatalog.step("rest", target: level == .experienced ? 45 : 60)
        let lunge = available.contains(.sandbag)
            ? ExerciseCatalog.step("sandbag", target: reps, load: load)
            : ExerciseCatalog.step("lunge", target: reps, substitution: "Sandbag lunge")
        let row = available.contains(.rower)
            ? ExerciseCatalog.step("row", target: 300 * factor)
            : ExerciseCatalog.step("march", target: tidy(120 * factor), substitution: "Row")
        let ski = available.contains(.skiErg)
            ? ExerciseCatalog.step("ski", target: 250 * factor)
            : ExerciseCatalog.step("walk", target: tidy(120 * factor), substitution: "SkiErg")
        let wallball = available.contains(.wallBall)
            ? ExerciseCatalog.step("wallball", target: reps, load: 3)
            : ExerciseCatalog.step("squat", target: reps, substitution: "Wall ball")
        var main: [WorkoutStep]
        switch family {
        case .engine: main = [run, squat, carry, rest]
        case .introduction:
            main = [ExerciseCatalog.step("walk", target: 120), squat, carry, rest]
        case .strength:
            let lunge = available.contains(.sandbag)
                ? ExerciseCatalog.step("sandbag", target: reps, load: load)
                : ExerciseCatalog.step("lunge", target: reps, substitution: "Sandbag lunge")
            let station: WorkoutStep
            if available.contains(.skiErg) { station = ExerciseCatalog.step("ski", target: 250 * factor) }
            else if available.contains(.rower) { station = ExerciseCatalog.step("row", target: 250 * factor) }
            else if available.contains(.wallBall) { station = ExerciseCatalog.step("wallball", target: reps, load: 3) }
            else if available.contains(.sled) { station = ExerciseCatalog.step("sled", target: 25, load: 10) }
            else { station = carry }
            main = [squat, lunge, station, rest]
        case .endurance:
            main = [run, rest]
        case .runCarry:
            main = [run, carry, rest]
        case .lowerBody:
            main = [squat, lunge, rest]
        case .bodyweight:
            main = [ExerciseCatalog.step("march", target: tidy(90 * factor)),
                    ExerciseCatalog.step("squat", target: reps),
                    ExerciseCatalog.step("walk", target: 90),
                    ExerciseCatalog.step("lunge", target: reps), rest]
        case .rowCircuit:
            main = [row, squat, rest]
        case .skiCircuit:
            main = [ski, run, rest]
        case .stationMix:
            main = [row, ski, carry, wallball, rest]
        case .runLunge:
            main = [run, lunge, rest]
        case .raceRehearsal:
            return raceRehearsal(preferences: preferences, load: load)
        case .chain:
            // Run → station → run → station: practising the change of gear is the point.
            let first = available.contains(.sled)
                ? ExerciseCatalog.step("sled", target: 25, load: load)
                : ExerciseCatalog.step("burpee", target: (20 * factor / 5).rounded() * 5)
            let second = available.contains(.wallBall)
                ? ExerciseCatalog.step("wallball", target: reps, load: 3)
                : lunge
            main = [run, first, fresh(run), second, rest]
            // In a short session one full chain would overrun, so keep a single run-and-station pair.
            let chainSeconds = main.reduce(0) { $0 + $1.estimatedSeconds }
            if chainSeconds > (Double(preferences.timeBudget) * 60 - 300) * 1.2 { main = [run, first, rest] }
        case .custom:
            main = [ExerciseCatalog.step("squat", target: reps), rest]
        case .easy:
            main = [ExerciseCatalog.step("walk", target: 180), ExerciseCatalog.step("squat", target: 6),
                    ExerciseCatalog.step("march", target: 60), ExerciseCatalog.step("rest", target: 60)]
        }
        let warmup = [ExerciseCatalog.step("walk", target: 180)]
        let cooldown = [ExerciseCatalog.step("cooldown", target: 120)]
        let availableSeconds = Double(preferences.timeBudget) * 60 - 300
        // A very short circuit would need more than 8 rounds to fill a long session: lengthen the circuit instead.
        let singleRound = main.reduce(0) { $0 + $1.estimatedSeconds }
        let copies = min(3, max(1, Int((availableSeconds / singleRound / 8).rounded(.up))))
        if copies > 1 { main = (0..<copies).flatMap { index in index == 0 ? main : main.map(fresh) } }
        let roundDuration = main.reduce(0) { $0 + $1.estimatedSeconds }
        let rounds = max(1, min(8, Int((availableSeconds / roundDuration).rounded())))
        return WorkoutDefinition(id: family.rawValue, family: family, title: family.title, purpose: family.purpose,
                                 level: level, timeBudget: preferences.timeBudget, rounds: rounds,
                                 warmup: warmup, main: main, cooldown: cooldown)
    }
    /// Rounds a timed target to the nearest 30 seconds so it reads as "4 min", not "234 sec".
    static func tidy(_ seconds: Double) -> Double { max(30, (seconds / 30).rounded() * 30) }
    /// Same step with its own identity, for circuits that repeat a movement.
    static func fresh(_ step: WorkoutStep) -> WorkoutStep { var copy = step; copy.id = UUID().uuidString; return copy }

    /// All eight stations in race order with a run before each. Distances are a share of the full
    /// course by level (half, three-quarters, full); loads stay at the athlete's own training level.
    static func raceRehearsal(preferences: AthletePreferences, load: Double) -> WorkoutDefinition {
        let level = preferences.level
        let share = level == .beginner ? 0.5 : (level == .regular ? 0.75 : 1.0)
        let kit = preferences.equipment
        func metres(_ full: Double, step: Double) -> Double { max(step, (full * share / step).rounded() * step) }
        func distance(_ id: String, _ full: Double, by step: Double, load: Double = 0) -> WorkoutStep {
            let exercise = ExerciseCatalog.find(id)
            let target = metres(full, step: step)
            let perUnit = exercise.defaultKind == .distance ? exercise.secondsPerUnit : 1.5
            return WorkoutStep(exerciseID: id, targetKind: .distance, target: target, loadKg: load,
                               estimatedSeconds: target * perUnit)
        }
        func timed(_ id: String, _ seconds: Double, instead: String) -> WorkoutStep {
            ExerciseCatalog.step(id, target: tidy(seconds * share), substitution: instead)
        }
        func run() -> WorkoutStep {
            kit.contains(.runningSpace) ? distance("run", 1000, by: 50) : timed("march", 420, instead: "1 km run")
        }
        let stations: [WorkoutStep] = [
            kit.contains(.skiErg) ? distance("ski", 1000, by: 50) : timed("walk", 300, instead: "SkiErg"),
            kit.contains(.sled) ? distance("sled", 50, by: 12.5, load: load) : timed("march", 120, instead: "Sled push"),
            kit.contains(.sled) ? distance("sledpull", 50, by: 12.5, load: load) : timed("march", 120, instead: "Sled pull"),
            distance("burpee", 80, by: 5),
            kit.contains(.rower) ? distance("row", 1000, by: 50) : timed("march", 300, instead: "Row"),
            kit.contains(.kettlebell) ? distance("carry", 200, by: 10, load: load) : timed("march", 150, instead: "Farmer’s carry"),
            kit.contains(.sandbag) ? distance("sandbag", 100, by: 5, load: load) : distance("lunge", 100, by: 5),
            kit.contains(.wallBall)
                ? ExerciseCatalog.step("wallball", target: (100 * share).rounded(), load: 3)
                : ExerciseCatalog.step("squat", target: (100 * share).rounded(), substitution: "Wall ball")
        ]
        let main = stations.flatMap { [run(), $0] }
        let family = WorkoutFamily.raceRehearsal
        let draft = WorkoutDefinition(id: family.rawValue, family: family, title: family.title, purpose: family.purpose,
                                      level: level, timeBudget: preferences.timeBudget, rounds: 1,
                                      warmup: [ExerciseCatalog.step("walk", target: 180)], main: main,
                                      cooldown: [ExerciseCatalog.step("cooldown", target: 120)])
        var workout = draft
        workout.timeBudget = draft.estimatedMinutes   // a rehearsal takes as long as it takes
        return workout
    }
}
