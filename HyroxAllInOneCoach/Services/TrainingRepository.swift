import Foundation
import Observation

@MainActor
protocol TrainingStorage {
    func load() throws -> TrainingSnapshot?
    func save(_ snapshot: TrainingSnapshot) throws
}

@MainActor
final class LocalTrainingStorage: TrainingStorage {
    private let fileURL: URL
    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = directory.appendingPathComponent("HybridTraining-v1.json")
    }
    func load() throws -> TrainingSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let snapshot = try decoder.decode(TrainingSnapshot.self, from: data)
        guard snapshot.version == 1, !snapshot.workouts.isEmpty,
              snapshot.workouts.allSatisfy({ $0.rounds > 0 && !$0.main.isEmpty && $0.expandedSteps.allSatisfy { $0.step.target > 0 } }),
              snapshot.workouts.contains(where: { $0.id == snapshot.selectedWorkoutID }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if let active = snapshot.active {
            guard active.cursor >= 0, active.cursor <= active.steps.count, active.workout.rounds > 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
        }
        return snapshot
    }
    func save(_ snapshot: TrainingSnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

@MainActor @Observable
final class TrainingRepository {
    private(set) var state = TrainingSnapshot()
    private(set) var storageError: String?
    private(set) var isReadable = false
    private(set) var createdFreshData = false
    @ObservationIgnored private let storage: any TrainingStorage

    init(storage: any TrainingStorage = LocalTrainingStorage()) {
        self.storage = storage
        reload()
    }
    var preferences: AthletePreferences { state.preferences }
    var workouts: [WorkoutDefinition] { state.workouts }
    var active: ActiveSession? { state.active }
    var sessions: [SessionRecord] { state.sessions.sorted { $0.startedAt > $1.startedAt } }
    var selectedWorkout: WorkoutDefinition? { state.workouts.first { $0.id == state.selectedWorkoutID } }

    func reload() {
        do {
            if let saved = try storage.load() { state = saved }
            else {
                var fresh = TrainingSnapshot()
                fresh.workouts = WorkoutFamily.starters.map { WorkoutFactory.make($0, preferences: fresh.preferences) }
                try storage.save(fresh)
                state = fresh
                createdFreshData = true
            }
            isReadable = true
            storageError = nil
            addMissingStarters()
        } catch {
            isReadable = false
            storageError = "Your saved data couldn’t be opened. Nothing has been replaced. Please try again."
            NSLog("Training storage could not be opened: %@", String(describing: error))
        }
    }
    @discardableResult
    private func commit(_ snapshot: TrainingSnapshot) -> Bool {
        guard isReadable else { return false }
        do {
            try storage.save(snapshot)
            state = snapshot
            storageError = nil
            return true
        } catch {
            storageError = "That change couldn’t be saved. Your previous data is safe. Please try again."
            NSLog("Training storage save failed: %@", String(describing: error))
            return false
        }
    }
    @discardableResult
    func selectWorkout(_ id: String) -> Bool {
        guard state.workouts.contains(where: { $0.id == id }) else { return false }
        var next = state
        next.selectedWorkoutID = id
        next.workoutRotation?.removeAll { $0 == id }
        return commit(next)
    }

    /// Selects saved starters without rebuilding them or changing an active session.
    @discardableResult
    func shuffleWorkout() -> Bool {
        guard isReadable, state.active == nil else { return false }
        let candidates = state.workouts.filter { $0.family != .custom && $0.id != state.selectedWorkoutID }
        let candidateIDs = Set(candidates.map(\.id))
        var remaining = (state.workoutRotation ?? []).filter { candidateIDs.contains($0) }
        if remaining.isEmpty { remaining = candidates.map(\.id).shuffled() }
        guard !remaining.isEmpty else { return false }
        var next = state
        next.selectedWorkoutID = remaining.removeFirst()
        next.workoutRotation = remaining
        return commit(next)
    }

    private func addMissingStarters() {
        let existingIDs = Set(state.workouts.map(\.id))
        let missing = WorkoutFamily.starters.filter { !existingIDs.contains($0.rawValue) }
        guard !missing.isEmpty else { return }
        var next = state
        next.workouts += missing.map { WorkoutFactory.make($0, preferences: state.preferences) }
        next.workoutRotation = nil
        _ = commit(next)
    }
    @discardableResult
    func saveWorkout(_ workout: WorkoutDefinition, preferences: AthletePreferences) -> Bool {
        var next = state
        guard let index = next.workouts.firstIndex(where: { $0.id == workout.id }) else { return false }
        next.workouts[index] = workout
        next.preferences = preferences
        return commit(next)
    }
    @discardableResult
    func storeCustomWorkout(_ workout: WorkoutDefinition) -> Bool {
        guard workout.family == .custom, !workout.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !workout.main.isEmpty, (1...12).contains(workout.rounds),
              workout.expandedSteps.count <= 500,
              workout.expandedSteps.allSatisfy({ $0.step.target.isFinite && $0.step.target > 0 }) else { return false }
        var next = state
        next.workouts.removeAll { $0.id == workout.id }
        next.workouts.append(workout)
        next.selectedWorkoutID = workout.id
        return commit(next)
    }
    @discardableResult
    func deleteCustomWorkout(_ id: String) -> Bool {
        guard state.workouts.contains(where: { $0.id == id && $0.family == .custom }),
              let starter = state.workouts.first(where: { $0.family != .custom }) else { return false }
        var next = state
        next.workouts.removeAll { $0.id == id }
        if next.selectedWorkoutID == id { next.selectedWorkoutID = starter.id }
        return commit(next)
    }
    @discardableResult
    func savePreferences(_ preferences: AthletePreferences) -> Bool {
        var next = state
        next.preferences = preferences
        return commit(next)
    }
    @discardableResult
    func completeOnboarding(preferences: AthletePreferences, journey: TrainingJourney, rebuildStarters: Bool) -> Bool {
        var next = state
        next.preferences = preferences
        next.journey = journey
        if rebuildStarters && next.active == nil {
            let custom = next.workouts.filter { $0.family == .custom }
            next.workouts = WorkoutFamily.starters.map { WorkoutFactory.make($0, preferences: preferences) } + custom
            next.workoutRotation = nil
            let family: WorkoutFamily = preferences.level == .beginner ? .introduction : .engine
            next.selectedWorkoutID = family.rawValue
        }
        return commit(next)
    }
    @discardableResult
    func saveJourney(_ journey: TrainingJourney) -> Bool {
        var next = state
        next.journey = journey
        return commit(next)
    }
    @discardableResult
    func updateActive(_ active: ActiveSession?) -> Bool {
        var next = state
        next.active = active
        return commit(next)
    }
    @discardableResult
    func saveSession(_ session: SessionRecord, finishingActive: Bool) -> Bool {
        var next = state
        next.sessions.removeAll { $0.id == session.id }
        next.sessions.append(session)
        if finishingActive, next.active?.id == session.id { next.active = nil }
        return commit(next)
    }
    @discardableResult
    func deleteSession(_ id: UUID) -> Bool {
        var next = state
        next.sessions.removeAll { $0.id == id }
        return commit(next)
    }
    func weekDays(now: Date = Date()) -> [TrainingDay] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let count = state.sessions.filter { $0.qualifiesForProgress && calendar.isDate($0.startedAt, inSameDayAs: date) }.count
            return TrainingDay(id: calendar.startOfDay(for: date), date: date, count: count, isToday: calendar.isDateInToday(date))
        }
    }
}

struct TrainingDay: Identifiable {
    let id: Date
    let date: Date
    let count: Int
    let isToday: Bool
}
