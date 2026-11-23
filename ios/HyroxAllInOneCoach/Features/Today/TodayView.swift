import SwiftUI

struct TodayView: View {
    @Environment(PlusPurchaseStore.self) private var plus
    @Environment(\.scenePhase) private var scenePhase
    @State private var pickedOnEntry = false
    let repository: TrainingRepository
    let engine: WorkoutSessionEngine
    @State private var sheet: TodaySheet?
    @State private var showingWorkout = false
    @State private var sessionsBeforePlayer: [SessionRecord] = []
    @State private var confirmStartFresh = false
    @State private var tab: TrainingTab = .today

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if tab == .plan {
                        TrainingPlanView(repository: repository) { sheet = .choose }
                    } else {
                        todayContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background { TrainingBackdrop() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if tab == .today, let workout = repository.selectedWorkout {
                        TodayNextAction(workout: workout, active: engine.active,
                                        units: repository.preferences.units, action: startWorkout)
                    }
                    TrainingTabBar(selection: $tab, coach: { sheet = .coach }, progress: { sheet = .rewards })
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $sheet) { destination in sheetContent(destination) }
            .fullScreenCover(isPresented: $showingWorkout, onDismiss: celebrateSavedWorkout) {
                WorkoutPlayerView(repository: repository, engine: engine)
            }
        }
        .onAppear {
            guard !pickedOnEntry else { return }
            pickedOnEntry = true
            _ = repository.shuffleWorkout()
        }
        .onChange(of: scenePhase) { previous, current in
            guard previous == .background, current == .active,
                  sheet == nil, !showingWorkout else { return }
            _ = repository.shuffleWorkout()
        }
    }
    @ViewBuilder private var todayContent: some View {
        header
        storageNotice
        if let workout = repository.selectedWorkout {
            TodayWorkoutCard(workout: workout, active: engine.active, units: repository.preferences.units,
                             adjust: { sheet = .adjust(workout) },
                             change: { sheet = .choose }, shuffle: { _ = repository.shuffleWorkout() })
                .trainingReveal(delay: 0.04)
            ExerciseGuidesTodayCard(workout: workout) { sheet = .demos }
            TrainingQuickActions(library: { sheet = .choose }, history: { sheet = .history })
                .trainingReveal(delay: 0.1)
            CoachTodayCard { sheet = .coach }.trainingReveal(delay: 0.12)
            if repository.state.journey?.rewardsEnabled != false {
                JourneyProgressCard(rewards: TrainingRewards(sessions: repository.sessions),
                                    journey: repository.state.journey ?? TrainingJourney()) { sheet = .rewards }
                    .trainingReveal(delay: 0.1)
            }
            WeeklyProgressCard(days: repository.weekDays()).trainingReveal(delay: 0.15)
            WorkoutOutlineView(workout: workout, units: repository.preferences.units)
            PlusToolsCard(isPlus: plus.isPlus) { sheet = .feature($0) }
            recentSessions
            footer
        } else {
            ContentUnavailableView("Your workouts are safe", systemImage: "externaldrive.badge.exclamationmark",
                                   description: Text("We couldn’t open your local training data. Try again below."))
            Button("Try again", action: repository.reload).buttonStyle(TrainingButtonStyle())
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                HybridBrand()
                Spacer(minLength: 6)
                Button { sheet = .preferences } label: {
                    Image(systemName: "slider.horizontal.3").font(.body)
                        .frame(width: 44, height: 44)
                        .background(TrainingTheme.surface, in: Circle())
                        .overlay(Circle().strokeBorder(TrainingTheme.border))
                }
                .buttonStyle(TrainingCardButtonStyle()).accessibilityLabel("Training preferences")
            }
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date(), format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                    Text("Today, your way.").font(.trainingDisplay()).textCase(.uppercase).tracking(-1.2)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 0)
                Button { sheet = .plus } label: {
                    Image(systemName: "sparkles").font(.title3).foregroundStyle(TrainingTheme.mint)
                        .frame(width: 44, height: 44)
                        .background(TrainingTheme.mint.opacity(0.1), in: Circle())
                }
                .buttonStyle(TrainingCardButtonStyle())
                .accessibilityLabel(plus.isPlus ? "Manage Hybrid Plus" : "Discover Hybrid Plus")
            }
        }
        .trainingReveal()
    }
    @ViewBuilder private var storageNotice: some View {
        if let error = repository.storageError {
            VStack(alignment: .leading, spacing: 10) {
                Label(error, systemImage: "exclamationmark.triangle").font(.body)
                Button("Try again", action: repository.reload).font(.headline)
                if !repository.isReadable {
                    Button("Start fresh (keeps a backup)") { confirmStartFresh = true }.font(.subheadline)
                }
            }
            .trainingPanel()
            .confirmationDialog("Start with fresh data?", isPresented: $confirmStartFresh, titleVisibility: .visible) {
                Button("Start fresh", role: .destructive) { _ = repository.startFresh() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your saved workouts and history can’t be opened. The damaged file is kept on this iPhone as a backup, and the app starts again with the starter sessions.")
            }
        }
    }
    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Recent sessions", subtitle: "Your effort, recorded.")
            if repository.sessions.isEmpty {
                HStack(alignment: .top, spacing: 14) {
                    SymbolTile(symbol: "checkmark.seal")
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your first session starts here.").font(.headline)
                        Text("Finish a workout to build your history. No pressure, no streak to protect.")
                            .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                    }
                }
                .trainingPanel()
            } else {
                VStack(spacing: 0) {
                    ForEach(repository.sessions.prefix(5)) { record in
                        Button { sheet = .session(record) } label: {
                            SessionHistoryRow(record: record)
                        }
                        .buttonStyle(.plain)
                        if record.id != repository.sessions.prefix(5).last?.id { Divider().overlay(TrainingTheme.border) }
                    }
                }
                .trainingPanel(padding: 16)
                if repository.sessions.count > 5 {
                    Button("View all \(repository.sessions.count) sessions") { sheet = .history }
                        .buttonStyle(TrainingButtonStyle(prominent: false))
                }
            }
        }
    }
    private var footer: some View {
        VStack(alignment: .leading, spacing: 16) {
            SafetyNote()
            Text("Made for hybrid training. Not affiliated with HYROX. Starter sessions are general training ideas, not personalized coaching.")
                .font(.caption).foregroundStyle(TrainingTheme.secondary)
        }
    }
    @ViewBuilder private func sheetContent(_ destination: TodaySheet) -> some View {
        switch destination {
        case .adjust(let workout):
            if workout.family == .custom { PlusFeatureView(repository: repository, feature: .builder, workout: workout) }
            else { AdjustWorkoutView(repository: repository, workout: workout) }
        case .choose: WorkoutChooserView(repository: repository)
        case .preferences: TrainingPreferencesView(repository: repository)
        case .session(let record): WorkoutSummaryView(repository: repository, engine: engine, record: record, isNew: false)
        case .history: SessionHistoryView(repository: repository, engine: engine)
        case .rewards: RewardsView(repository: repository)
        case .receipt(let receipt): RewardCelebrationView(receipt: receipt)
        case .plus: PlusPaywallView()
        case .coach: CoachView(repository: repository)
        case .demos: ExerciseGuideLibraryView()
        case .feature(let feature): PlusFeatureView(repository: repository, feature: feature)
        }
    }
    private func startWorkout() {
        sessionsBeforePlayer = repository.sessions
        if engine.active != nil { showingWorkout = true }
        else if let workout = repository.selectedWorkout, engine.start(workout) { showingWorkout = true }
    }
    private func celebrateSavedWorkout() {
        guard repository.state.journey?.rewardsEnabled != false else { return }
        let previousIDs = Set(sessionsBeforePlayer.map(\.id))
        guard let saved = repository.sessions.first(where: { !previousIDs.contains($0.id) && $0.qualifiesForProgress }) else { return }
        let before = TrainingRewards(sessions: sessionsBeforePlayer)
        let after = TrainingRewards(sessions: repository.sessions)
        let earnedBefore = Set(before.badges.filter(\.earned).map(\.id))
        let unlocked = after.badges.filter { $0.earned && !earnedBefore.contains($0.id) }
        sheet = .receipt(RewardReceipt(id: saved.id, points: TrainingRewards.points(for: saved),
                                       previousLevel: before.level, rewards: after, newBadges: unlocked))
    }
}

private enum TodaySheet: Identifiable {
    case adjust(WorkoutDefinition), choose, preferences, session(SessionRecord), history, rewards, receipt(RewardReceipt), plus, coach, demos, feature(PlusFeature)
    var id: String {
        switch self {
        case .adjust(let workout): "adjust-\(workout.id)"
        case .choose: "choose"
        case .preferences: "preferences"
        case .session(let record): "session-\(record.id)"
        case .history: "history"
        case .rewards: "rewards"
        case .receipt(let receipt): "receipt-\(receipt.id)"
        case .plus: "plus"
        case .coach: "coach"
        case .demos: "demos"
        case .feature(let feature): "feature-\(feature.id)"
        }
    }
}

struct SessionHistoryRow: View {
    let record: SessionRecord
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SymbolTile(symbol: record.workout.family.symbol)
            VStack(alignment: .leading, spacing: 5) {
                Text(record.workout.title).font(.headline).foregroundStyle(TrainingTheme.primary)
                Text(record.startedAt, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                if record.endedEarly { Text("Finished early").font(.caption).foregroundStyle(TrainingTheme.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 5) {
                Text(TrainingFormat.clock(record.durationSeconds)).font(.headline.monospacedDigit())
                    .foregroundStyle(TrainingTheme.primary)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(TrainingTheme.secondary)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
