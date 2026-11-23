import SwiftUI
import RevenueCat
import StoreKit

struct PlusPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PlusPurchaseStore.self) private var store
    @State private var selectedID = "$rc_annual"
    @State private var showingPrivacy = false
    @State private var showingManagement = false
    var focus: PlusFeature? = nil

    private var selected: Package? { store.packages.first { $0.identifier == selectedID } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    if PlusPurchaseStore.isTestStore { testNotice }
                    if store.isPlus { membership } else { plans; benefits }
                    FreePlusComparison()
                    policies
                }
                .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) { actionBar }
            .background { TrainingBackdrop() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showingPrivacy) { PlusPrivacyView() }
            .manageSubscriptionsSheet(isPresented: $showingManagement)
            .interactiveDismissDisabled(store.isWorking)
            .trainingScreen()
            .task { await store.loadPlans(); chooseAvailablePlan() }
            .onChange(of: store.packages.map(\.identifier)) { _, _ in chooseAvailablePlan() }
        }
    }
    /// "Train free for 7 days." when a plan offers this customer a trial.
    private var trialHeadline: String? {
        store.orderedPackages.compactMap { store.trialLength(for: $0) }.first.map { "Train free for \($0)." }
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 30) {
                HStack { PlusBadge(); Spacer() }
                Spacer(minLength: 45)
                Text(store.isPlus ? "Your Plus.\nYour possibilities." : (trialHeadline ?? "Your training.\nYour way."))
                    .font(.trainingDisplay()).textCase(.uppercase).tracking(-0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(focus?.pitch ?? "Build your own sessions. See the bigger picture.")
                    .font(.body).foregroundStyle(TrainingTheme.primary.opacity(0.85))
            }
            .padding(22).frame(maxWidth: .infinity, minHeight: 275, alignment: .leading)
            .background { TrainingAurora() }
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(TrainingTheme.border))
            .trainingReveal()
            PlusHeroGraphic().trainingReveal(delay: 0.12)
        }
    }
    private var benefits: some View {
        VStack(spacing: 20) {
            PlusBenefitRow(symbol: "square.stack.3d.up.fill", title: "Build a session that fits you",
                           detail: "Choose movements, targets and rest. Add warm-up, repeated rounds and cooldown. Save and reuse your own workouts.")
            PlusBenefitRow(symbol: "chart.bar.xaxis", title: "See your progress in context",
                           detail: "Explore weekly training minutes, your workout balance and how sessions felt—all from your saved history.")
        }
    }
    private var testNotice: some View {
        Label("Preview test store · Simulated purchases only. No real charges.", systemImage: "testtube.2")
            .font(.subheadline).foregroundStyle(TrainingTheme.mint).trainingPanel(padding: 14)
    }
    @ViewBuilder private var plans: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Choose your rhythm", subtitle: "Every plan includes every Plus feature.")
            if store.isLoading && store.packages.isEmpty {
                HStack { ProgressView(); Text("Loading available plans…").font(.body) }.frame(minHeight: 60)
            } else if store.packages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A plan for every rhythm.").font(.headline)
                    Text("Pricing isn’t available yet. Nothing will be charged here.").font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                }.trainingPanel()
            } else {
                ForEach(store.orderedPackages, id: \.identifier) { package in planRow(package) }
            }
            if let message = store.message { Text(message).font(.subheadline).foregroundStyle(TrainingTheme.secondary) }
        }
    }
    private func planTitle(_ package: Package) -> String {
        switch package.packageType {
        case .annual: return "Annual"
        case .weekly: return "Weekly"
        case .lifetime: return "Lifetime"
        default: return "Monthly"
        }
    }
    private func planPeriod(_ package: Package) -> String? {
        switch package.packageType {
        case .annual: return "year"
        case .weekly: return "week"
        case .lifetime: return nil
        default: return "month"
        }
    }
    private func planDetail(_ package: Package) -> String {
        switch package.packageType {
        case .annual: return "12 months of Hybrid Plus · Renews automatically"
        case .weekly: return "One week at a time · Renews automatically"
        case .lifetime: return "Pay once. Keep Hybrid Plus. No renewal"
        default: return "One month at a time · Renews automatically"
        }
    }
    private func billingLine(_ package: Package) -> String {
        let price = package.storeProduct.localizedPriceString
        guard let period = planPeriod(package) else { return "\(price) charged once. Not a subscription; nothing to cancel." }
        if let trial = store.trialLength(for: package) {
            return "Free for \(trial), then \(price) every \(period). Auto-renews; cancel in Apple subscription settings at least 24 hours before the trial ends to avoid being charged."
        }
        return "\(price) billed every \(period). Auto-renews; cancel in Apple subscription settings."
    }
    private func planRow(_ package: Package) -> some View {
        let chosen = selectedID == package.identifier
        let title = planTitle(package)
        let price = package.storeProduct.localizedPriceString
        let priceLine = planPeriod(package).map { "\(price) / \($0)" } ?? "\(price) once"
        let trial = store.trialLength(for: package)
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) { selectedID = package.identifier }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    if let savings = store.savings(for: package), savings > 0 { StatusPill(text: "Save ≈\(savings)%") }
                    Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                        .font(.title2).foregroundStyle(TrainingTheme.accent).accessibilityHidden(true)
                }
                Text(priceLine).font(.title2.weight(.bold))
                if let trial {
                    Text("\(trial) free, then \(priceLine)")
                        .font(.subheadline.weight(.medium)).foregroundStyle(TrainingTheme.accent)
                }
                if let equivalent = store.monthlyEquivalent(for: package) {
                    Text("Approx. \(equivalent)/month · Billed annually")
                        .font(.subheadline.weight(.medium)).foregroundStyle(TrainingTheme.accent)
                }
                Text(planDetail(package)).font(.subheadline).foregroundStyle(TrainingTheme.secondary)
                if let savings = store.savings(for: package), savings > 0 {
                    Text("About \(savings)% less than 12 monthly payments.")
                        .font(.footnote).foregroundStyle(TrainingTheme.secondary)
                }
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(chosen ? TrainingTheme.mint.opacity(0.08) : TrainingTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(chosen ? TrainingTheme.mint : TrainingTheme.border, lineWidth: chosen ? 2 : 1))
        }
        .buttonStyle(.plain).foregroundStyle(TrainingTheme.primary)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
    private var membership: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Hybrid Plus is active", systemImage: "checkmark.seal.fill").font(.title3.weight(.semibold))
            Text("Your builder and progress insights are unlocked. Thank you for supporting Hybrid Trainer.").font(.body)
            if store.expiration == nil { Text("Lifetime access. Nothing renews.").font(.subheadline).foregroundStyle(TrainingTheme.secondary) }
            if let date = store.expiration {
                Text("\(store.willRenew ? "Renews" : "Access until") \(date.formatted(date: .abbreviated, time: .omitted))").font(.subheadline).foregroundStyle(TrainingTheme.secondary)
            }
            Button("Manage subscription") { showingManagement = true }.frame(minHeight: 44)
            if let message = store.message { Text(message).font(.subheadline) }
        }.trainingPanel()
    }
    private var actionBar: some View {
        VStack(spacing: 10) {
            if store.isWorking || store.isLoading {
                HStack { ProgressView(); Text(store.isWorking ? "Waiting for confirmation…" : "Loading plans…") }
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 56)
            } else if store.isPlus {
                Button("Enjoy Hybrid Plus") { dismiss() }.buttonStyle(TrainingButtonStyle())
            } else if let selected {
                Button {
                    Task { await store.purchase(selected) }
                } label: { Label(PlusPurchaseStore.isTestStore ? "Test Hybrid Plus purchase" : (store.trialLength(for: selected) != nil ? "Start free trial" : "Get Hybrid Plus"), systemImage: "sparkles") }
                    .buttonStyle(TrainingButtonStyle())
                Text(billingLine(selected))
                    .font(.caption).foregroundStyle(TrainingTheme.secondary).multilineTextAlignment(.center)
            } else {
                Button("Try loading plans again") { Task { await store.loadPlans() } }.buttonStyle(TrainingButtonStyle())
            }
            if !store.isPlus { Button("Keep training for free") { dismiss() }.font(.subheadline).frame(minHeight: 32) }
        }
        .padding(.horizontal, 20).padding(.vertical, 12).background(TrainingTheme.background)
    }
    private var policies: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text((store.hasTrialOffer ? "A free trial becomes a paid subscription unless canceled at least 24 hours before the trial ends. " : "") + "Subscriptions renew automatically unless canceled at least 24 hours before the current period ends. Payment is charged at confirmation, or when a free trial ends. Lifetime is a one-time purchase. Manage or cancel in your Apple account settings.")
                .font(.footnote).foregroundStyle(TrainingTheme.secondary)
            Text("Your saved workouts and history remain yours if you cancel. Creating or editing custom templates and viewing Plus insights require active Plus access.")
                .font(.footnote).foregroundStyle(TrainingTheme.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { policyButtons }
                VStack(alignment: .leading, spacing: 6) { policyButtons }
            }
            Text("Apple Health, Watch tracking and personalized coaching are not included.")
                .font(.footnote).foregroundStyle(TrainingTheme.secondary)
        }
    }
    @ViewBuilder private var policyButtons: some View {
        if !store.isWorking {
            Button("Restore purchases") { Task { await store.restore() } }.frame(minHeight: 44)
        }
        Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!).frame(minHeight: 44)
        Button("Privacy") { showingPrivacy = true }.frame(minHeight: 44)
    }
    private func chooseAvailablePlan() {
        if selected == nil { selectedID = store.orderedPackages.first?.identifier ?? "$rc_annual" }
    }
}
