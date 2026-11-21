import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var headingFocused: Bool
    let repository: TrainingRepository
    var isReview = false
    @State private var page = 0
    @State private var movingForward = true
    @State private var preferences: AthletePreferences
    @State private var journey: TrainingJourney
    @State private var rebuildStarters: Bool

    init(repository: TrainingRepository, isReview: Bool = false) {
        self.repository = repository
        self.isReview = isReview
        _preferences = State(initialValue: repository.preferences)
        _journey = State(initialValue: repository.state.journey ?? TrainingJourney())
        _rebuildStarters = State(initialValue: repository.createdFreshData && !isReview)
    }
    var body: some View {
        VStack(spacing: 0) {
            navigation
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        pageContent
                        if let error = repository.storageError {
                            Text(error).font(.body).foregroundStyle(TrainingTheme.primary)
                        }
                    }
                    .padding(20).frame(maxWidth: 560).frame(maxWidth: .infinity)
                }
                .id(page)
                .transition(pageTransition)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .background { TrainingBackdrop() }
        .trainingScreen()
        .interactiveDismissDisabled(!isReview)
        .onChange(of: page) { _, _ in headingFocused = true }
    }
    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .offset(x: movingForward ? 32 : -32).combined(with: .opacity),
            removal: .offset(x: movingForward ? -32 : 32).combined(with: .opacity))
    }
    private var navigation: some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button { move(to: page - 1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous step")
            } else {
                Image(systemName: "h.circle.fill").font(.title).foregroundStyle(TrainingTheme.mint)
                    .frame(width: 44, height: 44).accessibilityHidden(true)
            }
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { step in
                    Capsule().fill(step <= page ? TrainingTheme.mint : TrainingTheme.border).frame(height: 4)
                }
            }
            .accessibilityElement(children: .ignore).accessibilityLabel("Setup step \(page + 1) of 5")
            if isReview {
                Button("Cancel") { dismiss() }.frame(minHeight: 44)
            } else {
                Button("Skip") { finish(useCurrentSetup: true) }.frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Skip setup and use current preferences")
            }
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 4)
    }
    @ViewBuilder private var pageContent: some View {
        switch page {
        case 0: welcome
        case 1: levelChoices
        case 2: rhythmChoices
        case 3: equipmentChoices
        default: ready
        }
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            WelcomeHeroView().accessibilityFocused($headingFocused)
            benefit("Small steps. Real momentum.", detail: "Guided sessions, flexible rest and a little celebration for every effort.", symbol: "sparkles")
                .trainingReveal(delay: 0.22)
            Label("No account needed · Works offline", systemImage: "checkmark.shield")
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
        }
    }
    private var levelChoices: some View {
        VStack(alignment: .leading, spacing: 22) {
            JourneyEmblem(symbol: "figure.strengthtraining.functional", progress: 0.4, compact: true)
            heading("Start where you are.", detail: "There’s no test to pass. Choose the starting point that feels right today.")
            ForEach(AthleteLevel.allCases) { level in
                ChoiceRow(title: level.title, detail: level.detail, selected: preferences.level == level) {
                    withAnimation(selectionAnimation) { preferences.level = level }
                }
            }
            SafetyNote()
        }
    }
    private var rhythmChoices: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Find your rhythm.", detail: "Make space for movement and recovery. These choices are a starting point, not a prescription.")
            SectionHeading(title: "What brings you here?")
            ForEach(TrainingGoal.allCases) { goal in
                ChoiceRow(title: goal.title, detail: goal.detail, selected: journey.goal == goal) {
                    withAnimation(selectionAnimation) { journey.goal = goal }
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(title: "Time for a session")
                Picker("Time for a session", selection: $preferences.timeBudget) {
                    ForEach([15, 25, 40], id: \.self) { Text("\($0) min").tag($0) }
                    if ![15, 25, 40].contains(preferences.timeBudget) {
                        Text("\(preferences.timeBudget) min").tag(preferences.timeBudget)
                    }
                }.pickerStyle(.segmented)
                Stepper("\(journey.weeklyDays) training days / week", value: $journey.weeklyDays, in: 1...4)
                    .font(.headline).frame(minHeight: 48)
                Text("A flexible aim, not a streak. Rest days never take away points or badges.")
                    .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }.trainingPanel()
        }
    }
    private var equipmentChoices: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Use what you have.", detail: "Pick the equipment you can access. No equipment? Leave everything unselected for bodyweight alternatives.")
            ForEach(Equipment.allCases) { item in
                ChoiceRow(title: item.title, selected: preferences.equipment.contains(item)) {
                    withAnimation(selectionAnimation) {
                        if preferences.equipment.contains(item) { preferences.equipment.remove(item) }
                        else { preferences.equipment.insert(item) }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Measurements").font(.headline)
                Picker("Measurements", selection: $preferences.units) {
                    ForEach(UnitSystem.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            }.trainingPanel()
        }
    }
    private var ready: some View {
        VStack(alignment: .leading, spacing: 22) {
            JourneyEmblem(symbol: "sparkles", progress: 1, compact: true)
            heading("Made for your momentum.", detail: "Your starting point is ready. You bring the effort. We’ll keep the next step clear.")
            TrainingBlueprintCard(preferences: preferences, journey: journey)
            HStack(alignment: .top, spacing: 14) {
                SymbolTile(symbol: "bolt.fill")
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your first win is waiting.").font(.headline)
                    Text("Save a session with a completed step to earn XP and unlock your First step badge. Recovery days never take that away.")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }
            }.trainingReveal(delay: 0.18)
            if repository.active == nil {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Apply choices to starter workouts", isOn: $rebuildStarters).font(.headline)
                    Text(rebuildStarters
                         ? "This rebuilds all four starter templates and replaces any template edits. Saved sessions are never changed."
                         : "Your current workout templates stay exactly as they are. Adjust any workout later to apply your new preferences.")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }.trainingPanel()
            }
            Text("Apple Health and Apple Watch are not connected in this version. Your training stays on this iPhone.")
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
        }
    }
    private var bottomBar: some View {
        VStack(spacing: 9) {
            Button {
                if page < 4 { move(to: page + 1) }
                else { finish(useCurrentSetup: false) }
            } label: {
                Label(page == 4 ? "Let’s train" : (page == 0 ? "Make it yours" : "Continue"),
                      systemImage: page == 4 ? "checkmark" : "arrow.right")
            }
            .buttonStyle(TrainingButtonStyle())
            Text(page == 4 ? "You can change these choices anytime." : "About a minute to make this your own.")
                .font(.caption).foregroundStyle(TrainingTheme.secondary)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
        .background(TrainingTheme.background)
    }
    private func heading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: page == 0 ? "Welcome to Hybrid Training" : "Make it yours · \(page + 1) / 5", color: TrainingTheme.mint)
            Text(title).font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader).accessibilityFocused($headingFocused)
            Text(detail).font(.body).foregroundStyle(TrainingTheme.secondary)
        }
    }
    private func benefit(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            SymbolTile(symbol: symbol)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
    private var selectionAnimation: Animation? { reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8) }
    private func move(to newPage: Int) {
        movingForward = newPage > page
        withAnimation(selectionAnimation) { page = newPage }
    }
    private func finish(useCurrentSetup: Bool) {
        let profile = useCurrentSetup ? (repository.state.journey ?? TrainingJourney()) : journey
        let prefs = useCurrentSetup ? repository.preferences : preferences
        if repository.completeOnboarding(preferences: prefs, journey: profile,
                                         rebuildStarters: !useCurrentSetup && rebuildStarters) {
            if isReview { dismiss() }
        }
    }
}
