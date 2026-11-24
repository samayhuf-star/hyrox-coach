import SwiftUI

struct CoachView: View {
    @Environment(CoachStore.self) private var coach
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let repository: TrainingRepository
    @State private var draft = ""
    @State private var shareWorkout = false
    @State private var sheet: CoachSheet?
    @FocusState private var composing: Bool
    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if coach.account.userId == nil { introduction } else { conversation }
                        Color.clear.frame(height: 1).id("latest")
                    }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: coach.turns.last?.status) { _, _ in
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { reader.scrollTo("latest", anchor: .bottom) }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { if coach.account.userId != nil { bottomPanel } }
            }
            .background { TrainingBackdrop() }.trainingScreen()
            .navigationTitle("Your Coach").navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(item: $sheet) { destination in sheetContent(destination) }
            .task(id: coach.account.userId) { await coach.load() }
            .onChange(of: coach.account.userId) { _, new in if new == nil { coach.resetPrivateState(); shareWorkout = false; draft = "" } }
        }
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 20) {
            CoachIntroduction()
            CoachSignInView()
            CoachNotice(text: "One credit per successful reply. Free credits reset monthly; purchased credits never expire. No automatic top-ups.")
            Button("Privacy & AI limitations") { sheet = .privacy }.frame(minHeight: 44)
        }
    }
    @ViewBuilder private var conversation: some View {
        if let wallet = coach.wallet { CoachCreditStrip(wallet: wallet) { sheet = .wallet } }
        if coach.turns.isEmpty { chatWelcome }
        ForEach(coach.turns) { turn in CoachTurnView(turn: turn) }
        if coach.sending { Label("Coach is thinking…", systemImage: "sparkles").font(.subheadline).foregroundStyle(TrainingTheme.accent) }
        if let message = coach.message {
            CoachNotice(text: message)
            if coach.retry != nil {
                Button("Recover my reply") { Task { await coach.retryReply() } }
                    .buttonStyle(TrainingButtonStyle(prominent: false)).disabled(coach.sending || coach.busy)
            }
        }
        if coach.busy { ProgressView("Refreshing Coach…").frame(maxWidth: .infinity) }
        if !coach.busy && coach.wallet == nil {
            Button("Reconnect to Coach") { Task { await coach.load() } }.buttonStyle(TrainingButtonStyle())
        }
    }
    private var chatWelcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            CoachIntroduction()
            Text("Where shall we start?").font(.headline)
            starter("Understand a movement", symbol: "figure.strengthtraining.traditional", text: "Explain how to do a farmer’s carry safely, with a lighter alternative.")
            starter("Adjust my session", symbol: "slider.horizontal.3", text: "How can I make a hybrid workout more manageable when I have less time?")
            starter("Make room for recovery", symbol: "leaf", text: "What are some simple ways to decide between a lighter session and a rest day?")
            Text("AI can make mistakes. This is general training guidance, not medical advice.")
                .font(.caption).foregroundStyle(TrainingTheme.secondary)
        }
    }
    private func starter(_ title: String, symbol: String, text: String) -> some View {
        Button { draft = text; composing = true } label: {
            HStack { Label(title, systemImage: symbol); Spacer(); Image(systemName: "arrow.up.left") }
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading).trainingPanel(padding: 16)
        }.buttonStyle(.plain)
    }
    @ViewBuilder private var bottomPanel: some View {
        if let wallet = coach.wallet {
            if !wallet.consented { consentPanel }
            else if wallet.total == 0 {
                VStack(spacing: 10) {
                    Text("All used for now. Your next 20 free replies arrive \(wallet.resetAt.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                    Button("View credit wallet") { sheet = .wallet }.buttonStyle(TrainingButtonStyle())
                }.padding(20).background(.regularMaterial)
            } else if coach.snapshot?.aiReady != true {
                VStack(spacing: 10) {
                    CoachNotice(text: "Coach’s AI connection is not ready yet. Your credits are untouched.")
                    Button("Refresh connection") { Task { await coach.load() } }.frame(minHeight: 44).disabled(coach.busy)
                }.padding(16).background(.regularMaterial)
            } else { composer }
        }
    }
    private var consentPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Before we talk").font(.headline)
            Text("Your messages and recent conversation are sent to Cloud and OpenAI to prepare replies. Don’t include sensitive medical or identifying information. Workout context is optional and off by default.")
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            Button("I agree · Continue to Coach") { Task { await coach.consent(true) } }
                .buttonStyle(TrainingButtonStyle()).disabled(coach.busy)
            Button("Read privacy details") { sheet = .privacy }.frame(minHeight: 44)
        }.padding(20).background(.regularMaterial)
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Share today’s workout", isOn: $shareWorkout).font(.subheadline).tint(TrainingTheme.accent)
            if shareWorkout {
                DisclosureGroup("Review what will be shared") {
                    Text(coach.workoutContext(repository)).font(.caption).foregroundStyle(TrainingTheme.secondary)
                }.font(.caption)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask your Coach…", text: $draft, axis: .vertical)
                    .lineLimit(1...4).focused($composing).padding(14)
                    .background(TrainingTheme.inset, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Question for AI Coach")
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.title3.bold()).foregroundStyle(.white)
                        .frame(width: 50, height: 50).background(TrainingTheme.actionGradient, in: Circle())
                }.disabled(!coach.canSend || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.utf16.count > 1600)
                    .accessibilityLabel("Send question, one credit per successful reply")
            }
            Text(draft.utf16.count > 1600 ? "Please shorten your question to 1,600 characters." : "1 credit per successful reply · AI guidance, not medical advice")
                .font(.caption).foregroundStyle(TrainingTheme.secondary)
        }.padding(16).background(.regularMaterial)
    }
    private func send() {
        let text = draft
        let context = shareWorkout ? coach.workoutContext(repository) : ""
        composing = false
        Task {
            await coach.send(text, context: context)
            if coach.turns.contains(where: { $0.question == text.trimmingCharacters(in: .whitespacesAndNewlines) && $0.status == "complete" }) { draft = "" }
        }
    }
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
        if coach.account.userId != nil {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New conversation", systemImage: "plus.bubble") { draft = ""; coach.newConversation() }
                    Button("Conversations", systemImage: "clock.arrow.circlepath") { sheet = .history }
                    Button("Credit wallet", systemImage: "sparkles") { sheet = .wallet }
                    Button("Coach account", systemImage: "person.crop.circle") { sheet = .account }
                } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel("Coach options")
            }
        }
    }
    @ViewBuilder private func sheetContent(_ sheet: CoachSheet) -> some View {
        switch sheet {
        case .wallet: CoachWalletView()
        case .history: CoachHistoryView()
        case .account: CoachAccountView()
        case .privacy: PlusPrivacyView()
        }
    }
}
private enum CoachSheet: String, Identifiable {
    case wallet, history, account, privacy
    var id: String { rawValue }
}
