import SwiftUI
@preconcurrency import RevenueCat

struct CoachWalletView: View {
    @Environment(CoachStore.self) private var coach
    @Environment(PlusPurchaseStore.self) private var plus
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let wallet = coach.wallet { balance(wallet) }
                    Text("More conversation, on your terms.").font(.title2.bold())
                    Text("One-time packs. No subscription. Purchased credits never expire and are used after your monthly free credits.")
                        .foregroundStyle(TrainingTheme.secondary)
                    packs
                    if let message = coach.message { CoachNotice(text: message) }
                    Button { Task { await coach.load() } } label: { Label("Refresh my wallet", systemImage: "arrow.clockwise") }
                        .buttonStyle(TrainingButtonStyle(prominent: false)).disabled(coach.busy || coach.purchasing)
                    CoachNotice(text: "Credits follow your Coach account. Sign in to the same email to recover your purchased balance; Apple’s restore does not recreate spent consumable credits. Hybrid Plus is separate.")
                    Text("No automatic purchases. A failed reply costs nothing. Refunded packs are deducted from your purchased balance, including any credits already used.")
                        .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }.padding(20)
            }.background { TrainingBackdrop() }.trainingScreen()
                .navigationTitle("Credit wallet").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .task { await coach.loadPacks() }
        }
    }
    private func balance(_ wallet: CoachWallet) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("YOUR COACH CREDITS", systemImage: "sparkles").font(.caption.weight(.bold)).foregroundStyle(TrainingTheme.accent)
            Text("\(wallet.total)").font(.largeTitle.bold().monospacedDigit())
            Text("replies available").font(.headline)
            ProgressView(value: Double(wallet.free), total: 20).tint(TrainingTheme.accent)
                .accessibilityLabel("Monthly free credits").accessibilityValue("\(wallet.free) of 20 remaining")
            HStack {
                TrainingMetricWell(value: "\(wallet.free) / 20", label: "Monthly free", symbol: "gift")
                TrainingMetricWell(value: "\(max(0, wallet.purchased))", label: "Purchased", symbol: "sparkles")
            }
            Text("20 free credits reset \(wallet.resetAt.formatted(date: .abbreviated, time: .shortened)). Unused free credits don’t roll over. Reset is the first of each month at 00:00 UTC, shown here in your local time.")
                .font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            if wallet.purchased < 0 { Text("Refund adjustment: \(wallet.purchased) purchased credits. Free credits remain available; new purchases first cover this adjustment.").font(.subheadline) }
            if wallet.pending { Label("One credit reserved while your reply is prepared", systemImage: "clock").font(.caption) }
        }.trainingPanel()
    }
    @ViewBuilder private var packs: some View {
        if coach.packages.isEmpty {
            CoachNotice(text: "Paid packs aren’t enabled yet. You can use your monthly free replies; no payment will be taken here.")
        } else {
            ForEach(coach.packages, id: \.identifier) { package in pack(package) }
        }
    }
    private func pack(_ package: Package) -> some View {
        let count = package.storeProduct.productIdentifier == "coach_credits_50" ? 50 : 150
        return VStack(alignment: .leading, spacing: 14) {
            Text("\(count) Coach credits").font(.title3.bold())
            Text("\(package.storeProduct.localizedPriceString) · One-time purchase").font(.headline)
            Button { Task { await coach.purchase(package, plus: plus) } } label: { Text(coach.purchasing ? "Confirming…" : "Buy \(count) credits") }
                .buttonStyle(TrainingButtonStyle()).disabled(coach.purchasing || coach.sending || coach.busy)
        }.trainingPanel()
    }
}
