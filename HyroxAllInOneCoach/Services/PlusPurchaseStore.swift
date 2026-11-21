import Foundation
import Observation
@preconcurrency import RevenueCat

@MainActor @Observable
final class PlusPurchaseStore {
    private(set) var isPlus = false
    private(set) var packages: [Package] = []
    private(set) var isLoading = false
    private(set) var isWorking = false
    private(set) var hasLoaded = false
    private(set) var message: String?
    private(set) var expiration: Date?
    private(set) var willRenew = false
    @ObservationIgnored private var listening = false

    static let entitlement = "hybrid_plus"
    static let offering = "hybrid_plus"
    // Public SDK keys, not server credentials. Test Store is simulator-debug only.
    init() {
        if !Purchases.isConfigured {
            Purchases.configure(withAPIKey: Self.isTestStore
                ? "test_FImDYZzNXpGERvxSKVkHtEFeADB"
                : "appl_FNdlfhpCzAJnTSzxiZbehUeEeuR")
        }
    }
    static var isTestStore: Bool {
        #if DEBUG && targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
    var monthly: Package? { packages.first { $0.packageType == .monthly } }
    var annual: Package? { packages.first { $0.packageType == .annual } }

    func listen() async {
        guard !listening else { return }
        listening = true
        defer { listening = false }
        for await info in Purchases.shared.customerInfoStream {
            if Task.isCancelled { return }
            apply(info)
        }
    }
    func refresh() async {
        do { apply(try await Purchases.shared.customerInfo()) }
        catch {
            if let expiration, expiration <= .now { isPlus = false }
        }
    }
    func loadPlans() async {
        guard !isLoading else { return }
        isLoading = true
        message = nil
        defer { isLoading = false; hasLoaded = true }
        do {
            let offerings = try await Purchases.shared.offerings()
            packages = (offerings.offering(identifier: Self.offering)?.availablePackages ?? [])
                .filter { $0.packageType == .annual || $0.packageType == .monthly }
            if packages.isEmpty {
                message = "Plans aren’t available yet. You can keep training for free and try again later."
            }
        } catch {
            message = "We couldn’t load the plans. Check your connection and try again. Free training is still available."
        }
    }
    func purchase(_ package: Package) async {
        guard !isWorking else { return }
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(result.customerInfo)
            if !result.userCancelled && !isPlus {
                message = "Your purchase is being confirmed. If it needs approval, Plus will unlock when it completes."
            }
        } catch {
            let code = (error as NSError).code
            if code == ErrorCode.purchaseCancelledError.rawValue { return }
            if code == ErrorCode.paymentPendingError.rawValue {
                message = "Your purchase is awaiting approval. No need to purchase again. Plus will unlock after confirmation."
            } else {
                message = "The purchase couldn’t be completed. Nothing has been unlocked. Please try again or restore purchases."
            }
        }
    }
    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            apply(try await Purchases.shared.restorePurchases())
            message = isPlus ? "Your Hybrid Plus access is restored." : "No active Hybrid Plus subscription was found."
        } catch {
            message = "We couldn’t restore purchases. Check your connection and try again."
        }
    }
    func purchaseCredits(_ package: Package, userId: String) async throws -> Bool {
        guard !isWorking else { throw CoachFailure(status: 0, message: "Another purchase is in progress. Please wait.", code: nil) }
        isWorking = true
        let previous = Purchases.shared.appUserID
        defer { isWorking = false }
        do {
            _ = try await Purchases.shared.logIn("coach_\(userId)")
            let result = try await Purchases.shared.purchase(package: package)
            let original = try await Purchases.shared.logIn(previous)
            apply(original.customerInfo)
            return !result.userCancelled
        } catch {
            if let restored = try? await Purchases.shared.logIn(previous) { apply(restored.customerInfo) }
            throw error
        }
    }
    func savings(for package: Package) -> Int? {
        guard package.packageType == .annual, let monthly,
              monthly.storeProduct.currencyCode == package.storeProduct.currencyCode else { return nil }
        let annualPrice = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue
        let monthlyPrice = NSDecimalNumber(decimal: monthly.storeProduct.price).doubleValue
        guard monthlyPrice > 0, annualPrice < monthlyPrice * 12 else { return nil }
        return Int((100 * (1 - annualPrice / (monthlyPrice * 12))).rounded())
    }
    func monthlyEquivalent(for package: Package) -> String? {
        guard package.packageType == .annual,
              package.storeProduct.price > 0,
              let currency = package.storeProduct.currencyCode else { return nil }
        let monthlyPrice = package.storeProduct.price / Decimal(12)
        return monthlyPrice.formatted(.currency(code: currency))
    }
    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[Self.entitlement]
        isPlus = entitlement?.isActive == true
        expiration = entitlement?.expirationDate
        willRenew = entitlement?.willRenew == true
    }
}
