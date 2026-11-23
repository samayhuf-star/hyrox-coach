import SwiftUI

struct JourneyProgressCard: View {
    let rewards: TrainingRewards
    let journey: TrainingJourney
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var days: Int { rewards.activeDaysThisWeek() }
    @State private var appeared = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Eyebrow(text: "Your momentum", color: TrainingTheme.mint)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }
                levelSummary
                ProgressView(value: Double(appeared || reduceMotion ? rewards.levelXP : 0), total: 250)
                    .tint(TrainingTheme.mint).accessibilityHidden(true)
                HStack(alignment: .top) {
                    Text("\(rewards.nextLevelXP) XP to your next level")
                    Spacer(minLength: 6)
                    Text("\(days) / \(journey.weeklyDays) days").foregroundStyle(TrainingTheme.mint)
                }.font(.caption).foregroundStyle(TrainingTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).trainingPanel()
        }
        .buttonStyle(TrainingCardButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your journey. Level \(rewards.level), \(rewards.totalXP) experience points. \(days) of \(journey.weeklyDays) training days this week. View achievements.")
        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(0.15)) { appeared = true } }
    }
    private var levelSummary: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            ZStack {
                Circle().stroke(TrainingTheme.mint.opacity(0.14), lineWidth: 5)
                Circle().trim(from: 0, to: Double(appeared || reduceMotion ? rewards.levelXP : 0) / 250)
                    .stroke(TrainingTheme.mint.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(rewards.level)").font(.title2.weight(.bold).monospacedDigit())
            }.frame(width: 64, height: 64).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(rewards.levelTitle).font(.title3.weight(.bold))
                Text("Level \(rewards.level) · \(rewards.totalXP) XP earned")
                    .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RewardsView: View {
    @Environment(\.dismiss) private var dismiss
    let repository: TrainingRepository
    @State private var showingSettings = false
    private var rewards: TrainingRewards { TrainingRewards(sessions: repository.sessions) }
    private var journey: TrainingJourney { repository.state.journey ?? TrainingJourney() }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    levelCard.trainingReveal()
                    weeklyQuest.trainingReveal(delay: 0.06)
                    badgeCollection.trainingReveal(delay: 0.12)
                    rewardRules
                }
                .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .navigationTitle("Your journey").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("Journey preferences")
                }
            }
            .sheet(isPresented: $showingSettings) { JourneySettingsView(repository: repository) }
            .trainingScreen()
        }
    }
    private var levelCard: some View {
        VStack(spacing: 14) {
            JourneyEmblem(symbol: "bolt.fill", progress: Double(rewards.levelXP) / 250, compact: true)
            StatusPill(text: "Level \(rewards.level)")
            Text(rewards.levelTitle).font(.title.weight(.bold)).multilineTextAlignment(.center)
            Text("\(rewards.totalXP) XP").font(.title2.monospacedDigit().weight(.semibold)).foregroundStyle(TrainingTheme.mint)
            Text("\(rewards.nextLevelXP) XP to level \(rewards.level + 1)")
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            ProgressView(value: Double(rewards.levelXP), total: 250).tint(TrainingTheme.mint)
                .accessibilityLabel("Level progress").accessibilityValue("\(rewards.levelXP) of 250 XP")
        }.frame(maxWidth: .infinity).trainingPanel()
    }
    private var weeklyQuest: some View {
        let days = rewards.activeDaysThisWeek()
        let complete = days >= journey.weeklyDays
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeading(title: "Your weekly rhythm", subtitle: journey.goal.title)
                Image(systemName: complete ? "checkmark.circle.fill" : "calendar")
                    .font(.title2).foregroundStyle(TrainingTheme.mint).accessibilityHidden(true)
            }
            HStack(spacing: 10) {
                ForEach(0..<journey.weeklyDays, id: \.self) { day in
                    Image(systemName: day < days ? "checkmark" : "circle.dotted")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .foregroundStyle(day < days ? TrainingTheme.background : TrainingTheme.secondary)
                        .background(day < days ? TrainingTheme.mint : TrainingTheme.background,
                                    in: RoundedRectangle(cornerRadius: 12))
                }
            }.accessibilityElement(children: .ignore).accessibilityLabel("\(days) of \(journey.weeklyDays) training days this week")
            Text(complete ? "Rhythm found. Enjoy your recovery—you’ve earned it." : "\(days) of \(journey.weeklyDays) days. One saved session with a completed step counts for the day.")
                .font(.body).foregroundStyle(TrainingTheme.secondary)
            Button("Adjust my weekly rhythm") { showingSettings = true }.font(.headline).frame(minHeight: 44)
        }.trainingPanel()
    }
    private var badgeCollection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Small wins, real progress", subtitle: "\(rewards.badges.filter(\.earned).count) of \(rewards.badges.count) badges earned")
            ForEach(rewards.badges) { badge in BadgeRow(badge: badge) }
        }
    }
    private var rewardRules: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Effort, not intensity", systemImage: "heart.fill").font(.headline)
            Text("A saved session with at least one completed step earns 50 XP, plus 5 XP per completed step, capped at 100 XP. Every 250 XP adds a level. Walking, recovery and early finishes count.")
            Text("There are no streak penalties or leaderboards. Editing or deleting saved sessions updates points and badges to match your history.")
        }.font(.subheadline).foregroundStyle(TrainingTheme.secondary)
    }
}

struct BadgeRow: View {
    let badge: TrainingBadge
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: badge.symbol).font(.title2)
                .foregroundStyle(badge.earned ? TrainingTheme.mint : TrainingTheme.secondary)
                .frame(width: 52, height: 58)
                .background(badge.earned ? TrainingTheme.mint.opacity(0.1) : TrainingTheme.background,
                            in: RoundedRectangle(cornerRadius: 15)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(badge.title).font(.headline)
                Text(badge.detail).font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                if badge.earned {
                    Label("Earned", systemImage: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(TrainingTheme.mint)
                } else {
                    ProgressView(value: badge.progress).tint(TrainingTheme.mint).accessibilityHidden(true)
                    Text("\(min(badge.current, badge.target)) / \(badge.target)").font(.caption.monospacedDigit())
                        .foregroundStyle(TrainingTheme.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).trainingPanel(padding: 16)
        .accessibilityElement(children: .combine)
    }
}

struct RewardCelebrationView: View {
    @Environment(\.dismiss) private var dismiss
    let receipt: RewardReceipt
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    emblem
                    Eyebrow(text: "Workout saved", color: TrainingTheme.mint)
                    Text(receipt.leveledUp ? "A new level.\nA stronger foundation." : "A little effort.\nA real step forward.")
                        .font(.trainingDisplay()).textCase(.uppercase).multilineTextAlignment(.center)
                    Text("+\(receipt.points) XP").font(.largeTitle.monospacedDigit().weight(.bold))
                        .foregroundStyle(TrainingTheme.mint).trainingReveal(delay: 0.15)
                    Text("Level \(receipt.rewards.level) · \(receipt.rewards.levelTitle)").font(.headline)
                    ProgressView(value: Double(receipt.rewards.levelXP), total: 250).tint(TrainingTheme.mint)
                        .accessibilityLabel("\(receipt.rewards.levelXP) of 250 XP toward the next level")
                    ForEach(receipt.newBadges) { badge in BadgeRow(badge: badge).trainingReveal(delay: 0.25) }
                    Text("Rest days never take away your progress. Take a breath and recover well.")
                        .font(.body).foregroundStyle(TrainingTheme.secondary).multilineTextAlignment(.center)
                }
                .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                Button("Back to Today") { dismiss() }.buttonStyle(TrainingButtonStyle())
                    .padding(20).background(TrainingTheme.background)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .trainingScreen()
        }
    }
    private var emblem: some View {
        JourneyEmblem(symbol: receipt.leveledUp ? "bolt.fill" : "checkmark.seal.fill", progress: 1)
            .overlay { RewardConfetti() }
    }
}
