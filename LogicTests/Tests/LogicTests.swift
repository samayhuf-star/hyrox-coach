import XCTest
import Foundation
@testable import HyroxCore

@MainActor final class MemoryStorage: TrainingStorage {
    var saved: TrainingSnapshot?
    var failSaves = false
    var saves = 0
    func load() throws -> TrainingSnapshot? { saved }
    func save(_ snapshot: TrainingSnapshot) throws {
        if failSaves { throw CocoaError(.fileWriteNoPermission) }
        saved = snapshot; saves += 1
    }
}

final class FactoryTests: XCTestCase {
    static let equipmentSets: [(String, Set<Equipment>)] = [
        ("none", []), ("default", [.runningSpace, .kettlebell]), ("all", Set(Equipment.allCases))
    ]
    @MainActor func prefs(_ level: AthleteLevel, _ budget: Int, _ kit: Set<Equipment>) -> AthletePreferences {
        var p = AthletePreferences(); p.level = level; p.timeBudget = budget; p.equipment = kit; return p
    }

    @MainActor func testEveryStarterIsValidForEveryProfile() async {
        var count = 0
        for family in WorkoutFamily.starters { for level in AthleteLevel.allCases { for budget in [15, 25, 40] {
            for (_, kit) in Self.equipmentSets {
                let w = WorkoutFactory.make(family, preferences: prefs(level, budget, kit))
                count += 1
                XCTAssertTrue((1...8).contains(w.rounds), "\(family) rounds \(w.rounds)")
                XCTAssertFalse(w.main.isEmpty)
                for s in w.expandedSteps {
                    XCTAssertTrue(s.step.target.isFinite && s.step.target > 0, "\(family) bad target")
                    XCTAssertTrue(s.step.estimatedSeconds > 0)
                }
                XCTAssertEqual(Set(w.expandedSteps.map(\.id)).count, w.expandedSteps.count, "\(family) duplicate step ids")
                // No kit the athlete doesn't own may appear.
                XCTAssertTrue(Set(w.equipment).isSubset(of: kit), "\(family)/\(level) uses kit not selected: \(w.equipment)")
            }
        } } }
        XCTAssertEqual(count, WorkoutFamily.starters.count * 3 * 3 * 3)
    }

    /// The session should land close to the time the athlete said they have.
    @MainActor func testEstimatedTimeStaysNearTimeBudget() async {
        var offenders: [String] = []
        // The race rehearsal is a fixed course, so it is deliberately not fitted to the time budget.
        let fitted = WorkoutFamily.starters.filter { $0 != .raceRehearsal }
        var builds = 0
        for family in fitted { for level in AthleteLevel.allCases { for budget in [15, 25, 40] {
            for (name, kit) in Self.equipmentSets {
                let w = WorkoutFactory.make(family, preferences: prefs(level, budget, kit))
                builds += 1
                let diff = w.estimatedMinutes - budget
                if abs(diff) * 100 > budget * 25 {
                    offenders.append("\(family.rawValue) \(level.rawValue) kit=\(name) budget=\(budget) est=\(w.estimatedMinutes) rounds=\(w.rounds)")
                }
            }
        } } }
        print("BUDGET_OFFENDERS \(offenders.count) of \(builds)")
        offenders.forEach { print("  OFF \($0)") }
        XCTAssertTrue(offenders.isEmpty, "\(offenders.count) of \(builds) starter builds miss the time budget by more than 25%")
    }

    /// Targets shown to the athlete should be clean numbers.
    @MainActor func testTargetsAreReadable() async {
        var ugly = Set<String>()
        for family in WorkoutFamily.starters { for level in AthleteLevel.allCases { for (_, kit) in Self.equipmentSets {
            for units in UnitSystem.allCases {
                let w = WorkoutFactory.make(family, preferences: prefs(level, 25, kit))
                for s in w.expandedSteps {
                    let text = s.step.targetText(units: units)
                    let rawSeconds = s.step.targetKind == .time && s.step.target >= 60 && !text.contains("min")
                    let oddTime = s.step.targetKind == .time && Int(s.step.target) % 15 != 0
                    let fraction = text.replacingOccurrences(of: ".5 m", with: " m").contains(".")   // 37.5 m = 3 sled lengths
                    if rawSeconds || oddTime || fraction { ugly.insert("\(units.rawValue): \(s.step.title) → \(text)") }
                }
            }
        } } }
        print("UGLY_TARGETS \(ugly.count)")
        ugly.sorted().forEach { print("  UGLY \($0)") }
        XCTAssertTrue(ugly.isEmpty, "\(ugly.count) distinct awkward target labels")
    }

    @MainActor func testFormatting() async {
        XCTAssertEqual(TrainingFormat.clock(0), "00:00")
        XCTAssertEqual(TrainingFormat.clock(59.9), "00:59")
        XCTAssertEqual(TrainingFormat.clock(3725), "1:02:05")
        XCTAssertEqual(TrainingFormat.clock(-5), "00:00")
        XCTAssertEqual(TrainingFormat.duration(120), "2 min")
        XCTAssertEqual(TrainingFormat.duration(45), "45 sec")
        XCTAssertEqual(TrainingFormat.duration(234), "3 min 54 sec")
        XCTAssertEqual(UnitSystem.imperial.displayDistance(400), 435)
        XCTAssertEqual(UnitSystem.imperial.displayLoad(4), 9)
        XCTAssertEqual(UnitSystem.metric.displayDistance(37.5), 37.5)
        XCTAssertEqual(UnitSystem.imperial.meters(UnitSystem.imperial.distanceValue(400)), 400, accuracy: 1e-9)
        XCTAssertEqual(UnitSystem.imperial.kilograms(UnitSystem.imperial.loadValue(12)), 12, accuracy: 1e-9)
    }
}

final class EngineTests: XCTestCase {
    @MainActor func make(_ family: WorkoutFamily = .engine) -> (MemoryStorage, TrainingRepository, WorkoutSessionEngine, WorkoutDefinition) {
        let storage = MemoryStorage()
        let repo = TrainingRepository(storage: storage)
        let engine = WorkoutSessionEngine(repository: repo)
        return (storage, repo, engine, repo.workouts.first { $0.family == family }!)
    }

    @MainActor func testStartOnlyOnce() async {
        let (_, _, engine, w) = make()
        XCTAssertTrue(engine.start(w))
        XCTAssertFalse(engine.start(w))
        XCTAssertEqual(engine.active?.cursor, 0)
    }

    @MainActor func testTimedStepAutoAdvancesAtItsBoundary() async {
        let (_, _, engine, w) = make()
        let t0 = Date()
        engine.start(w, now: t0)                       // step 0 = 180 s warm-up walk
        engine.tick(at: t0.addingTimeInterval(179))
        XCTAssertEqual(engine.active?.cursor, 0)
        engine.tick(at: t0.addingTimeInterval(185))
        XCTAssertEqual(engine.active?.cursor, 1)
        XCTAssertEqual(engine.active?.results.first?.elapsedSeconds ?? 0, 180, accuracy: 0.001)
        XCTAssertEqual(engine.active?.results.first?.status, .completed)
        // 5 s of the next step already elapsed
        XCTAssertEqual(engine.active!.stepElapsed(at: t0.addingTimeInterval(185)), 5, accuracy: 0.001)
    }

    @MainActor func testCatchUpAcrossSeveralTimedStepsAfterBackgrounding() async {
        let (_, _, engine, w) = make(.easy)             // walk180 | walk180, squat6, march60, rest60 ...
        let t0 = Date()
        engine.start(w, now: t0)
        engine.tick(at: t0.addingTimeInterval(400))     // 180 + 180 done, squat (reps) blocks
        XCTAssertEqual(engine.active?.cursor, 2)
        XCTAssertEqual(engine.active!.totalElapsed(at: t0.addingTimeInterval(400)), 400, accuracy: 0.001)
        XCTAssertEqual(engine.active!.stepElapsed(at: t0.addingTimeInterval(400)), 40, accuracy: 0.001)
    }

    @MainActor func testPauseExcludesPausedTime() async throws {
        let (_, _, engine, w) = make()
        engine.start(w, now: Date())
        engine.togglePause()
        XCTAssertTrue(engine.active!.isPaused)
        let frozen = engine.active!.totalElapsed(at: Date().addingTimeInterval(500))
        XCTAssertLessThan(frozen, 1)
        engine.tick(at: Date().addingTimeInterval(500)) // must not advance while paused
        XCTAssertEqual(engine.active?.cursor, 0)
        engine.togglePause()
        XCTAssertFalse(engine.active!.isPaused)
    }

    @MainActor func testAdvanceSkipUndoAndFinish() async {
        let (_, repo, engine, w) = make()
        engine.start(w, now: Date().addingTimeInterval(-10))
        let total = w.expandedSteps.count
        engine.advance()                                 // warm-up, manual
        engine.advance(skipped: true)
        XCTAssertEqual(engine.active?.results.map(\.status), [.completed, .skipped])
        engine.undo()
        XCTAssertEqual(engine.active?.cursor, 1)
        XCTAssertEqual(engine.active?.results.count, 1)
        XCTAssertTrue(engine.active!.isPaused, "undo pauses")
        engine.togglePause()
        while engine.active?.summary == nil { engine.advance() }
        let summary = engine.active!.summary!
        XCTAssertEqual(summary.results.count, total)
        XCTAssertFalse(summary.endedEarly)
        XCTAssertEqual(summary.completedCount, total)
        XCTAssertEqual(Set(summary.results.map(\.id)).count, total)
        XCTAssertTrue(repo.saveSession(summary, finishingActive: true))
        XCTAssertNil(repo.active)
        XCTAssertEqual(repo.sessions.count, 1)
        engine.advance(); engine.undo(); engine.endEarly(); engine.togglePause() // no session: must be harmless
        XCTAssertNil(repo.active)
    }

    @MainActor func testDistanceAndRepStepsRecordPlannedOrLoggedTarget() async {
        let (_, _, engine, w) = make()
        engine.start(w)
        engine.advance()                                 // warm-up
        let run = engine.active!.current!.step
        engine.logActual(target: 123, load: nil)
        engine.advance()
        XCTAssertEqual(engine.active?.results.last?.actualTarget, 123)
        let squat = engine.active!.current!.step
        engine.advance()
        XCTAssertEqual(engine.active?.results.last?.actualTarget, squat.target)
        XCTAssertEqual(engine.active?.results.last?.actualLoadKg, squat.loadKg > 0 ? squat.loadKg : nil)
        XCTAssertNotEqual(run.targetKind, .time)
    }

    @MainActor func testEndEarly() async {
        let (_, _, engine, w) = make()
        engine.start(w)
        engine.advance()
        engine.endEarly()
        let s = engine.active!.summary!
        XCTAssertTrue(s.endedEarly)
        XCTAssertEqual(s.completedCount, 1)
        XCTAssertEqual(s.skippedCount, 1)
        XCTAssertTrue(s.qualifiesForProgress)
        engine.undo()                                    // reopen the session
        XCTAssertNil(engine.active?.summary)
        XCTAssertEqual(engine.active?.cursor, 1)
    }

    @MainActor func testEndEarlyWithNothingDoneDoesNotQualify() async {
        let (_, _, engine, w) = make()
        engine.start(w)
        engine.endEarly()
        XCTAssertFalse(engine.active!.summary!.qualifiesForProgress)
        XCTAssertEqual(TrainingRewards.points(for: engine.active!.summary!), 0)
    }

    /// Phone left in a pocket / app killed mid-session on a manual (reps or distance) step.
    @MainActor func testForgottenSessionDurationIsBounded() async {
        let (_, _, engine, w) = make()
        let sixHoursAgo = Date().addingTimeInterval(-6 * 3600)
        engine.start(w, now: sixHoursAgo)
        engine.tick()                                    // app reopened
        XCTAssertEqual(engine.active?.autoPaused, true, "the long silent step is paused for the athlete")
        XCTAssertTrue(engine.active!.isPaused)
        XCTAssertEqual(engine.active!.stepAccumulatedSeconds, WorkoutSessionEngine.idleLimit(for: engine.active!.current!.step), accuracy: 0.001)
        engine.togglePause()                             // athlete taps resume
        XCTAssertNil(engine.active?.autoPaused)
        while engine.active?.summary == nil { engine.advance() }
        let minutes = engine.active!.summary!.durationSeconds / 60
        print("FORGOTTEN_SESSION_MINUTES \(Int(minutes)) (estimated \(w.estimatedMinutes))")
        XCTAssertLessThan(minutes, Double(w.estimatedMinutes) * 3, "a \(w.estimatedMinutes)-min workout was logged as \(Int(minutes)) min")
    }

    @MainActor func testUndoKeepsTotalTimeHonest() async {
        let (_, _, engine, w) = make()
        let t0 = Date().addingTimeInterval(-100)
        engine.start(w, now: t0)
        engine.advance()                                 // ~100 s on warm-up
        let before = engine.active!.totalAccumulatedSeconds
        engine.undo()
        XCTAssertEqual(engine.active!.totalAccumulatedSeconds, before, accuracy: 1)
        XCTAssertEqual(engine.active!.stepAccumulatedSeconds, 0)
    }

    @MainActor func testSaveFailureDoesNotCorruptState() async {
        let (storage, repo, engine, w) = make()
        engine.start(w)
        storage.failSaves = true
        engine.advance()
        XCTAssertEqual(repo.active?.cursor, 0, "state must not move when the save failed")
        XCTAssertNotNil(repo.storageError)
        storage.failSaves = false
        engine.advance()
        XCTAssertEqual(repo.active?.cursor, 1)
        XCTAssertNil(repo.storageError)
    }

    @MainActor func testEveryStarterRunsStartToFinish() async {
        for family in WorkoutFamily.starters {
            let (_, repo, engine, w) = make(family)
            XCTAssertTrue(engine.start(w), "\(family)")
            var guardCount = 0
            while engine.active?.summary == nil, guardCount < 1000 { engine.advance(); guardCount += 1 }
            XCTAssertEqual(engine.active?.summary?.results.count, w.expandedSteps.count, "\(family)")
            XCTAssertTrue(repo.saveSession(engine.active!.summary!, finishingActive: true))
        }
    }
}

final class RepositoryTests: XCTestCase {
    @MainActor func testFreshInstallSeedsTwelveStarters() async {
        let storage = MemoryStorage()
        let repo = TrainingRepository(storage: storage)
        XCTAssertTrue(repo.isReadable); XCTAssertTrue(repo.createdFreshData)
        XCTAssertEqual(repo.workouts.count, WorkoutFamily.starters.count)
        XCTAssertNotNil(repo.selectedWorkout)
        XCTAssertNil(repo.state.journey)
        let again = TrainingRepository(storage: storage)
        XCTAssertFalse(again.createdFreshData)
        XCTAssertEqual(again.state, repo.state)
    }

    @MainActor func testSnapshotSurvivesJSONRoundTrip() async throws {
        let storage = MemoryStorage()
        let repo = TrainingRepository(storage: storage)
        let engine = WorkoutSessionEngine(repository: repo)
        engine.start(repo.selectedWorkout!, now: Date(timeIntervalSince1970: 1_700_000_000))
        engine.advance()
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .millisecondsSince1970
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .millisecondsSince1970
        let back = try dec.decode(TrainingSnapshot.self, from: enc.encode(repo.state))
        XCTAssertEqual(back.workouts, repo.state.workouts)
        XCTAssertEqual(back.active?.cursor, 1)
        XCTAssertEqual(back.active?.results, repo.state.active?.results)
    }

    @MainActor func testOldSnapshotWithoutNewFieldsStillOpens() async throws {
        let json = """
        {"version":1,"preferences":{"level":"beginner","timeBudget":25,"equipment":["runningSpace"],"units":"metric","haptics":true,"sound":false},
         "workouts":[],"selectedWorkoutID":"engine","sessions":[]}
        """
        let snap = try JSONDecoder().decode(TrainingSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(snap.journey); XCTAssertNil(snap.workoutRotation)
    }

    @MainActor func testOnboardingRebuildsStartersAndPicksByLevel() async {
        let repo = TrainingRepository(storage: MemoryStorage())
        var p = repo.preferences; p.level = .experienced; p.timeBudget = 40; p.equipment = Set(Equipment.allCases)
        XCTAssertTrue(repo.completeOnboarding(preferences: p, journey: TrainingJourney(), rebuildStarters: true))
        XCTAssertEqual(repo.state.selectedWorkoutID, "engine")
        XCTAssertTrue(repo.workouts.allSatisfy { $0.level == .experienced })
        p.level = .beginner
        repo.completeOnboarding(preferences: p, journey: TrainingJourney(), rebuildStarters: true)
        XCTAssertEqual(repo.state.selectedWorkoutID, "introduction")
    }

    @MainActor func testShuffleCyclesThroughEveryStarterBeforeRepeating() async {
        let repo = TrainingRepository(storage: MemoryStorage())
        var seen: [String] = []
        let others = WorkoutFamily.starters.count - 1
        for _ in 0..<others { XCTAssertTrue(repo.shuffleWorkout()); seen.append(repo.state.selectedWorkoutID) }
        XCTAssertEqual(Set(seen).count, others, "every other starter once, no repeats in a cycle")
        XCTAssertFalse(seen.contains("engine"))
    }

    @MainActor func testShuffleBlockedDuringActiveSession() async {
        let repo = TrainingRepository(storage: MemoryStorage())
        WorkoutSessionEngine(repository: repo).start(repo.selectedWorkout!)
        XCTAssertFalse(repo.shuffleWorkout())
    }

    @MainActor func testCustomWorkoutRules() async {
        let repo = TrainingRepository(storage: MemoryStorage())
        var c = WorkoutFactory.make(.custom, preferences: repo.preferences)
        c.id = "custom-1"; c.title = "Mine"
        XCTAssertTrue(repo.storeCustomWorkout(c))
        XCTAssertEqual(repo.state.selectedWorkoutID, "custom-1")
        var bad = c; bad.id = "custom-2"; bad.rounds = 13
        XCTAssertFalse(repo.storeCustomWorkout(bad))
        bad.rounds = 2; bad.title = "  "
        XCTAssertFalse(repo.storeCustomWorkout(bad))
        bad.title = "x"; bad.main[0].target = 0
        XCTAssertFalse(repo.storeCustomWorkout(bad))
        bad.main[0].target = .infinity
        XCTAssertFalse(repo.storeCustomWorkout(bad))
        XCTAssertFalse(repo.deleteCustomWorkout("engine"), "starters can't be deleted")
        XCTAssertTrue(repo.deleteCustomWorkout("custom-1"))
        XCTAssertNotNil(repo.selectedWorkout)
    }

    /// Deleting or editing the workout that is currently being performed.
    @MainActor func testDeletingCustomWorkoutMidSession() async {
        let repo = TrainingRepository(storage: MemoryStorage())
        var c = WorkoutFactory.make(.custom, preferences: repo.preferences); c.id = "custom-1"; c.title = "Mine"
        repo.storeCustomWorkout(c)
        let engine = WorkoutSessionEngine(repository: repo)
        engine.start(c)
        XCTAssertTrue(repo.deleteCustomWorkout("custom-1"))
        while engine.active?.summary == nil { engine.advance() }   // session carries its own copy
        XCTAssertEqual(engine.active?.summary?.results.count, c.expandedSteps.count)
    }

    @MainActor func testRewardsAndInsights() async {
        let repo = TrainingRepository(storage: MemoryStorage())
        let engine = WorkoutSessionEngine(repository: repo)
        for family in [WorkoutFamily.engine, .easy, .strength] {
            let w = repo.workouts.first { $0.family == family }!
            engine.start(w, now: Date().addingTimeInterval(-600))
            while engine.active?.summary == nil { engine.advance() }
            repo.saveSession(engine.active!.summary!, finishingActive: true)
        }
        let r = TrainingRewards(sessions: repo.sessions)
        XCTAssertEqual(r.qualifying.count, 3)
        XCTAssertEqual(r.totalXP, 300)                   // 50 + capped 50 each
        XCTAssertEqual(r.level, 2); XCTAssertEqual(r.levelXP, 50); XCTAssertEqual(r.nextLevelXP, 200)
        let earned = Set(r.badges.filter(\.earned).map(\.id))
        XCTAssertEqual(earned, ["first", "recovery", "variety", "full"])
        XCTAssertEqual(r.activeDaysThisWeek(), 1)
        let insights = TrainingInsights(sessions: repo.sessions, weekCount: 8)
        XCTAssertEqual(insights.weeks.count, 8)
        XCTAssertEqual(insights.weeks.reduce(0) { $0 + $1.sessions }, 3)
        XCTAssertEqual(insights.mix.count, 3)
        XCTAssertEqual(insights.trainingDays, 1)
        XCTAssertEqual(insights.totalMinutes, 30, accuracy: 1)
        let days = repo.weekDays()
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.filter(\.isToday).count, 1)
        XCTAssertEqual(days.reduce(0) { $0 + $1.count }, 3)
    }

    /// The real on-disk store: a damaged file must never be silently replaced, and the user needs a way out.
    @MainActor func testDamagedFileIsNotOverwritten() async throws {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("HybridTraining-v1.json")
        try? FileManager.default.removeItem(at: url)
        let good = TrainingRepository()
        XCTAssertTrue(good.isReadable)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try Data("{ not json".utf8).write(to: url)
        let broken = TrainingRepository()
        XCTAssertFalse(broken.isReadable)
        XCTAssertNotNil(broken.storageError)
        XCTAssertFalse(broken.savePreferences(AthletePreferences()), "writes are blocked while unreadable")
        XCTAssertEqual(try Data(contentsOf: url), Data("{ not json".utf8), "damaged file left untouched")
        broken.reload()
        XCTAssertFalse(broken.isReadable, "retry cannot recover a damaged file – user is stuck")
        try? FileManager.default.removeItem(at: url)
    }

    @MainActor func testStartFreshKeepsABackupOfTheDamagedFile() async throws {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("HybridTraining-v1.json")
        let backups = { try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.contains(".damaged-") } }
        for name in try backups() { try FileManager.default.removeItem(at: dir.appendingPathComponent(name)) }
        try Data("{ not json".utf8).write(to: url)
        let repo = TrainingRepository()
        XCTAssertFalse(repo.isReadable)
        XCTAssertTrue(repo.startFresh())
        XCTAssertTrue(repo.isReadable); XCTAssertNil(repo.storageError)
        XCTAssertEqual(repo.workouts.count, WorkoutFamily.starters.count)
        let kept = try backups()
        XCTAssertEqual(kept.count, 1)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(kept[0])), Data("{ not json".utf8))
        XCTAssertFalse(repo.startFresh(), "refused while data is healthy")
        try? FileManager.default.removeItem(at: url)
        for name in kept { try? FileManager.default.removeItem(at: dir.appendingPathComponent(name)) }
    }

    /// People who installed before the race workouts existed get them added, with nothing else touched.
    @MainActor func testExistingInstallGainsNewStarters() async {
        let storage = MemoryStorage()
        var old = TrainingSnapshot()
        old.workouts = [WorkoutFamily.engine, .easy].map { WorkoutFactory.make($0, preferences: old.preferences) }
        old.journey = TrainingJourney()
        storage.saved = old
        let repo = TrainingRepository(storage: storage)
        XCTAssertEqual(Set(repo.workouts.map(\.id)), Set(WorkoutFamily.starters.map(\.rawValue)))
        XCTAssertEqual(repo.state.selectedWorkoutID, "engine")
        XCTAssertNotNil(repo.state.journey)
    }

    @MainActor func testSavedSessionFromOlderVersionStillOpens() async throws {
        let repo = TrainingRepository(storage: MemoryStorage())
        WorkoutSessionEngine(repository: repo).start(repo.selectedWorkout!)
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .millisecondsSince1970
        var object = try JSONSerialization.jsonObject(with: enc.encode(repo.state.active!)) as! [String: Any]
        object.removeValue(forKey: "autoPaused")
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .millisecondsSince1970
        let back = try dec.decode(ActiveSession.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(back.autoPaused)
    }
}

final class RaceContentTests: XCTestCase {
    @MainActor func testRaceRehearsalFollowsTheOfficialCourseAtFullLevel() async {
        var p = AthletePreferences(); p.level = .experienced; p.equipment = Set(Equipment.allCases)
        let w = WorkoutFactory.make(.raceRehearsal, preferences: p)
        XCTAssertEqual(w.rounds, 1)
        XCTAssertEqual(w.main.count, 16)
        let runs = stride(from: 0, to: 16, by: 2).map { w.main[$0] }
        XCTAssertTrue(runs.allSatisfy { $0.exerciseID == "run" && $0.target == 1000 }, "8 runs of 1 km")
        let stations = stride(from: 1, to: 16, by: 2).map { w.main[$0] }
        // Order and distances checked against the 2026/27 Singles rulebook, section 4.1.
        XCTAssertEqual(stations.map(\.exerciseID), ["ski", "sled", "sledpull", "burpee", "row", "carry", "sandbag", "wallball"])
        XCTAssertEqual(stations.map(\.target), [1000, 50, 50, 80, 1000, 200, 100, 100])
        XCTAssertEqual(stations.map(\.targetKind), [.distance, .distance, .distance, .distance, .distance, .distance, .distance, .repetitions])
        XCTAssertEqual(Set(w.expandedSteps.map(\.id)).count, w.expandedSteps.count)
        XCTAssertEqual(w.timeBudget, w.estimatedMinutes)
    }

    @MainActor func testRaceRehearsalScalesByLevelAndWorksWithoutKit() async {
        var p = AthletePreferences(); p.level = .beginner; p.equipment = Set(Equipment.allCases)
        let half = WorkoutFactory.make(.raceRehearsal, preferences: p)
        XCTAssertEqual(stride(from: 1, to: 16, by: 2).map { half.main[$0].target }, [500, 25, 25, 40, 500, 100, 50, 50])
        XCTAssertEqual(half.main[0].target, 500)
        p.equipment = []
        let bare = WorkoutFactory.make(.raceRehearsal, preferences: p)
        XCTAssertEqual(bare.main.count, 16)
        XCTAssertTrue(bare.equipment.isEmpty, "no kit needed")
        XCTAssertTrue(bare.expandedSteps.allSatisfy { $0.step.target > 0 && $0.step.estimatedSeconds > 0 })
        XCTAssertEqual(bare.main[7].exerciseID, "burpee")
    }

    @MainActor func testChainAlternatesRunAndStation() async {
        var p = AthletePreferences(); p.level = .regular; p.timeBudget = 40; p.equipment = Set(Equipment.allCases)
        let w = WorkoutFactory.make(.chain, preferences: p)
        XCTAssertEqual(w.main.map(\.exerciseID), ["run", "sled", "run", "wallball", "rest"])
        XCTAssertNotEqual(w.main[0].id, w.main[2].id)
        p.timeBudget = 15; p.level = .experienced; p.equipment = [.runningSpace]
        XCTAssertEqual(WorkoutFactory.make(.chain, preferences: p).main.map(\.exerciseID), ["run", "burpee", "rest"])
    }

    @MainActor func testNewStationsAreInTheCatalogue() async {
        XCTAssertEqual(ExerciseCatalog.find("sledpull").title, "Sled pull")
        XCTAssertEqual(ExerciseCatalog.find("burpee").title, "Burpee broad jump")
        XCTAssertEqual(Set(ExerciseCatalog.all.map(\.id)).count, ExerciseCatalog.all.count)
    }
}
