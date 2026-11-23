import SwiftUI

struct CoachEmblem: View {
    var body: some View {
        ZStack {
            Circle().fill(TrainingTheme.actionGradient)
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.title2).foregroundStyle(.white)
        }.frame(width: 58, height: 58).accessibilityHidden(true)
    }
}
struct CoachTodayCard: View {
    @Environment(CoachStore.self) private var coach
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 15) {
                HStack { CoachEmblem(); Spacer(); StatusPill(text: "AI COACH") }
                Text("Meet your Coach").font(.title2.bold())
                Text("A little clarity. A better session.").font(.headline).foregroundStyle(TrainingTheme.accent)
                Text("Movement cues, manageable adjustments and room for recovery.")
                    .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                HStack {
                    Label(coach.wallet.map { "\($0.total) replies available" } ?? "20 free replies each month", systemImage: "sparkles")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }.font(.subheadline.weight(.semibold))
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background { TrainingAurora() }
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(TrainingTheme.border))
        }.buttonStyle(TrainingCardButtonStyle()).accessibilityElement(children: .combine)
    }
}
struct CoachIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { CoachEmblem(); Spacer(); StatusPill(text: "AI · NOT A HUMAN TRAINER") }
            Text("Meet your\nCoach.").font(.trainingDisplay()).textCase(.uppercase)
            Text("Questions welcome.\nPressure not included.").font(.title3.weight(.semibold)).foregroundStyle(TrainingTheme.accent)
            Text("Understand a movement, adapt your session, or make space for rest. A training assistant in your corner—not a substitute for professional care.")
                .font(.body).foregroundStyle(TrainingTheme.secondary)
            Label("20 free replies every month", systemImage: "sparkles").font(.headline)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background { TrainingAurora() }.clipShape(RoundedRectangle(cornerRadius: 26))
    }
}
struct CoachNotice: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading).trainingPanel(padding: 16)
    }
}
struct CoachCreditStrip: View {
    let wallet: CoachWallet
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").foregroundStyle(TrainingTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(wallet.total) replies available").font(.headline)
                    Text("\(wallet.free) free · \(max(0, wallet.purchased)) purchased").font(.caption).foregroundStyle(TrainingTheme.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(TrainingTheme.secondary)
            }.trainingPanel(padding: 14)
        }.buttonStyle(.plain).accessibilityHint("Opens your credit wallet")
    }
}
struct CoachTurnView: View {
    let turn: CoachTurn
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("YOU").font(.caption.weight(.bold)).foregroundStyle(TrainingTheme.accent)
                Text(turn.question).font(.body).textSelection(.enabled)
                if !turn.context.isEmpty { Label("Workout context shared", systemImage: "checkmark.shield").font(.caption).foregroundStyle(TrainingTheme.secondary) }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(TrainingTheme.accentSoft, in: RoundedRectangle(cornerRadius: 20))
            if let answer = turn.answer {
                VStack(alignment: .leading, spacing: 10) {
                    Label("COACH · AI", systemImage: "sparkles").font(.caption.weight(.bold)).foregroundStyle(TrainingTheme.accent)
                    Text(answer).font(.body).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).trainingPanel(padding: 18)
            } else {
                Text(turn.status == "pending" ? "Preparing your reply…" : "No reply saved. Your reserved credit was returned.")
                    .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }
        }.accessibilityElement(children: .contain)
    }
}
