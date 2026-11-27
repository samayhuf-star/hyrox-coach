import SwiftUI

@main
struct HybridTrainingApp: App {
    @State private var repository: TrainingRepository
    @State private var engine: WorkoutSessionEngine
    @State private var plus = PlusPurchaseStore()
    @State private var coach = CoachStore()

    init() {
        let repository = TrainingRepository()
        _repository = State(initialValue: repository)
        _engine = State(initialValue: WorkoutSessionEngine(repository: repository))
        PushService.startIfConsented()
    }
    var body: some Scene {
        WindowGroup {
            TrainingRootView(repository: repository, engine: engine)
                .environment(plus)
                .environment(coach)
                .onOpenURL { url in Task { await coach.account.openCallback(url) } }
                .task { await plus.refresh() }
                .task { await plus.listen() }
                .trainingScreen()
        }
    }
}

struct TrainingRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PlusPurchaseStore.self) private var plus
    let repository: TrainingRepository
    let engine: WorkoutSessionEngine
    @State private var enteredWithoutActiveSession: Bool

    init(repository: TrainingRepository, engine: WorkoutSessionEngine) {
        self.repository = repository
        self.engine = engine
        _enteredWithoutActiveSession = State(initialValue: repository.active == nil)
    }
    var body: some View {
        Group {
            if repository.isReadable && repository.state.journey == nil && enteredWithoutActiveSession && engine.active == nil {
                OnboardingView(repository: repository)
                    .transition(.opacity)
            } else {
                TodayView(repository: repository, engine: engine)
                    .transition(.opacity)
            }
        }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: repository.state.journey == nil)
            .task {
                engine.tick(notify: false)
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(500)) }
                    catch { return }
                    if scenePhase == .active { engine.tick() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    engine.tick(notify: false)
                    Task { await plus.refresh() }
                }
            }
    }
}
