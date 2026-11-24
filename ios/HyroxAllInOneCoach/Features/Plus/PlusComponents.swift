import SwiftUI

enum PlusFeature: String, Identifiable {
    case builder, insights
    var id: String { rawValue }
    var title: String { self == .builder ? "Custom workout builder" : "Progress insights" }
    var symbol: String { self == .builder ? "square.stack.3d.up.fill" : "chart.bar.xaxis" }
    var pitch: String {
        self == .builder ? "Make room for the way you like to train." : "Turn your saved sessions into a clearer picture."
    }
}

struct PlusBadge: View {
    var body: some View {
        Label("HYBRID PLUS", systemImage: "sparkles")
            .font(.caption.weight(.bold)).tracking(1)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(TrainingTheme.mint)
            .background(TrainingTheme.mint.opacity(0.1), in: Capsule())
    }
}

struct PlusBenefitRow: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SymbolTile(symbol: symbol)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.body).foregroundStyle(TrainingTheme.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PlusHeroGraphic: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Label("YOUR SESSION", systemImage: "square.stack.3d.up").font(.caption2.weight(.bold)).tracking(1)
                block("Warm up", symbol: "figure.walk", width: 0.8)
                block("Work + rest", symbol: "figure.run", width: 1)
                block("Cool down", symbol: "leaf", width: 0.65)
            }
            .padding(14).frame(maxWidth: .infinity)
            .background(TrainingTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .rotationEffect(.degrees(reduceMotion ? 0 : -3))
            VStack(alignment: .leading, spacing: 12) {
                Label("THE BIG PICTURE", systemImage: "chart.bar.xaxis").font(.caption2.weight(.bold)).tracking(0.5)
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(1...6, id: \.self) { number in
                        Capsule().fill(TrainingTheme.mint.opacity(number == 6 ? 1 : 0.25 + Double(number) * 0.08))
                            .frame(height: (appeared ? CGFloat(20 + number * 9) : 5))
                    }
                }.frame(height: 74)
                Text("Your effort, in view.").font(.caption).foregroundStyle(TrainingTheme.secondary)
            }
            .padding(14).frame(maxWidth: .infinity)
            .background(TrainingTheme.mint.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            .rotationEffect(.degrees(reduceMotion ? 0 : 3))
        }
        .foregroundStyle(TrainingTheme.mint)
        .background { Ellipse().fill(TrainingTheme.mint.opacity(0.06)).blur(radius: 30) }
        .accessibilityHidden(true)
        .onAppear { withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) { appeared = true } }
    }
    private func block(_ title: String, symbol: String, width: Double) -> some View {
        Label(title, systemImage: symbol).font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TrainingTheme.mint.opacity(width * 0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct FreePlusComparison: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A useful free app.\nMore room with Plus.").font(.title3.weight(.semibold))
            comparison("Daily workouts & starter edits", plusOnly: false)
            comparison("Timer, saved history & rewards", plusOnly: false)
            Divider().overlay(TrainingTheme.border)
            comparison("Create your own workout templates", plusOnly: true)
            comparison("Detailed progress insights", plusOnly: true)
        }.trainingPanel()
    }
    private func comparison(_ title: String, plusOnly: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: plusOnly ? "sparkles" : "checkmark.circle").foregroundStyle(TrainingTheme.mint)
            Text(title).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            Text(plusOnly ? "PLUS" : "FREE").font(.caption.weight(.bold))
                .foregroundStyle(plusOnly ? TrainingTheme.mint : TrainingTheme.secondary)
        }.accessibilityElement(children: .combine)
    }
}

struct PlusPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Your training stays on your iPhone.").font(.title2.bold())
                    policy("Training data", "Your workouts, saved results, effort ratings and notes are stored locally on this iPhone. They are not uploaded to RevenueCat. This app does not connect to Apple Health or Apple Watch.")
                    policy("Purchases", "Apple processes App Store payments. RevenueCat manages subscription access using a randomly generated app user identifier, purchase information, and device/app information needed for its service. The app does not receive your payment-card details.")
                    policy("Your choices", "You can edit or delete saved sessions and custom workouts in the app. Removing the app removes its local training data; it does not cancel your Apple subscription. Manage subscriptions through your Apple account settings.")
                    policy("AI Coach (optional)", "Coach uses a verified email account. Cloud stores your account, credit ledger and conversations. After your consent, your messages and up to six recent replies are sent to OpenAI for text generation. Today's workout is shared only when you turn on the sharing control; saved history, effort ratings, notes and Health data are not uploaded automatically. OpenAI API requests use store:false; this does not promise zero provider retention. Do not send sensitive medical or identifying information. AI can make mistakes and is not a human trainer or medical professional.")
                    policy("Coach credits & deletion", "You receive 20 free replies per UTC calendar month, with no rollover. A successful saved reply uses one credit. Optional purchased credits never expire and are used after free credits. Failed replies release reserved credits. Coach history and balances follow your account. Delete conversations or your account from Coach options. Account deletion removes chats and forfeits unused purchased credits; minimal hashed allowance and transaction identifiers remain to prevent duplicate grants and process refunds. It does not delete your local workouts or cancel Hybrid Plus.")
                    Link("OpenAI privacy policy", destination: URL(string: "https://openai.com/policies/privacy-policy/")!)
                    Link("RevenueCat privacy policy", destination: URL(string: "https://www.revenuecat.com/privacy")!)
                    Link("Apple privacy policy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                }.padding(20)
            }
            .navigationTitle("Privacy").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .trainingScreen()
        }
    }
    private func policy(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(detail).font(.body).foregroundStyle(TrainingTheme.secondary)
        }
    }
}
