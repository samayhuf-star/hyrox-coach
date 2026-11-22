import Foundation
import Observation
import UIKit
import AudioToolbox

@MainActor @Observable
final class WorkoutSessionEngine {
    let repository: TrainingRepository
    init(repository: TrainingRepository) { self.repository = repository }
    var active: ActiveSession? { repository.active }

    @discardableResult
    func start(_ workout: WorkoutDefinition, now: Date = Date()) -> Bool {
        guard active == nil else { return false }
        let session = ActiveSession(workout: workout, startedAt: now, runningSince: now)
        return repository.updateActive(session)
    }
    func tick(at now: Date = Date(), notify: Bool = true) {
        guard var session = active, session.summary == nil, session.runningSince != nil else { return }
        var changed = false
        while let current = session.current, current.step.targetKind == .time,
              session.stepElapsed(at: now) >= current.step.target {
            guard let since = session.runningSince else { break }
            let remaining = max(0, current.step.target - session.stepAccumulatedSeconds)
            let boundary = since.addingTimeInterval(remaining)
            session.settle(at: boundary)
            appendResult(to: &session, status: .completed)
            session.cursor += 1
            resetStep(&session)
            changed = true
            if session.current == nil {
                prepareSummary(&session, endedEarly: false, at: boundary)
                break
            }
        }
        if let current = session.current, session.summary == nil, current.step.targetKind != .time,
           let since = session.runningSince {
            // A reps/distance step never ends on its own. If nothing has happened for far longer than it
            // should take (phone pocketed, app closed), stop the clock there instead of logging hours.
            let limit = Self.idleLimit(for: current.step)
            if session.stepElapsed(at: now) > limit {
                session.settle(at: since.addingTimeInterval(max(0, limit - session.stepAccumulatedSeconds)))
                session.runningSince = nil
                session.autoPaused = true
                _ = repository.updateActive(session)
                return
            }
        }
        if changed, repository.updateActive(session), notify { transitionFeedback() }
    }
    /// Longest a manual step may run unattended: three times its estimate, and never under 10 minutes.
    static func idleLimit(for step: WorkoutStep) -> Double { max(600, step.estimatedSeconds * 3) }
    func togglePause() {
        tick()
        guard var session = active, session.summary == nil else { return }
        let now = Date()
        if session.runningSince == nil { session.runningSince = now }
        else { session.settle(at: now); session.runningSince = nil }
        session.autoPaused = nil
        repository.updateActive(session)
    }
    func advance(skipped: Bool = false) {
        let intendedStepID = active?.current?.id
        tick()
        guard var session = active, session.summary == nil, session.current?.id == intendedStepID,
              session.current != nil else { return }
        let now = Date()
        session.settle(at: now)
        appendResult(to: &session, status: skipped ? .skipped : .completed)
        session.cursor += 1
        resetStep(&session)
        if session.current == nil { prepareSummary(&session, endedEarly: false, at: now) }
        if repository.updateActive(session) { transitionFeedback() }
    }
    func undo() {
        guard var session = active, !session.results.isEmpty else { return }
        session.settle(at: Date())
        let previous = session.results.removeLast()
        session.cursor = max(0, session.cursor - 1)
        session.summary = nil
        session.runningSince = nil
        session.stepAccumulatedSeconds = 0
        session.actualTarget = previous.actualTarget
        session.actualLoadKg = previous.actualLoadKg
        repository.updateActive(session)
    }
    func logActual(target: Double?, load: Double?) {
        guard var session = active, session.summary == nil else { return }
        session.actualTarget = target
        session.actualLoadKg = load
        repository.updateActive(session)
    }
    func endEarly() {
        tick()
        guard var session = active, session.summary == nil else { return }
        let now = Date()
        session.settle(at: now)
        if session.current != nil {
            appendResult(to: &session, status: .skipped)
            session.cursor += 1
            resetStep(&session)
        }
        prepareSummary(&session, endedEarly: true, at: now)
        repository.updateActive(session)
    }
    @discardableResult
    func updateSummary(_ record: SessionRecord) -> Bool {
        guard var session = active, session.id == record.id, session.summary != nil else { return false }
        session.summary = record
        return repository.updateActive(session)
    }
    @discardableResult
    func discard() -> Bool { repository.updateActive(nil) }

    private func appendResult(to session: inout ActiveSession, status: StepStatus) {
        guard let current = session.current else { return }
        let manualTarget = current.step.targetKind == .time ? nil : (session.actualTarget ?? current.step.target)
        let result = StepResult(id: current.id, status: status,
                                elapsedSeconds: session.stepAccumulatedSeconds,
                                actualTarget: status == .completed ? manualTarget : session.actualTarget,
                                actualLoadKg: session.actualLoadKg ?? (current.step.loadKg > 0 ? current.step.loadKg : nil))
        session.results.append(result)
    }
    private func resetStep(_ session: inout ActiveSession) {
        session.autoPaused = nil
        session.stepAccumulatedSeconds = 0
        session.actualTarget = nil
        session.actualLoadKg = nil
    }
    private func prepareSummary(_ session: inout ActiveSession, endedEarly: Bool, at now: Date) {
        session.runningSince = nil
        session.summary = SessionRecord(id: session.id, workout: session.workout, startedAt: session.startedAt,
                                        endedAt: now, durationSeconds: session.totalAccumulatedSeconds,
                                        results: session.results, endedEarly: endedEarly, note: "")
    }
    private func transitionFeedback() {
        if repository.preferences.haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        if repository.preferences.sound { AudioServicesPlaySystemSound(1104) }
    }
}
