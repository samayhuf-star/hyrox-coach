import Foundation
import Observation
@preconcurrency import RevenueCat

@MainActor @Observable
final class CoachStore {
    let account = CoachAccount()
    private(set) var snapshot: CoachSnapshot?
    private(set) var busy = false
    private(set) var sending = false
    private(set) var purchasing = false
    private(set) var packages: [Package] = []
    private(set) var retry: CoachPending?
    var message: String?
    private var conversationId: String?
    private let api = CoachAPI()
    var wallet: CoachWallet? { snapshot?.wallet }
    var turns: [CoachTurn] { snapshot?.turns ?? [] }
    var canSend: Bool { account.userId != nil && !busy && !sending && !purchasing && retry == nil && wallet?.pending != true }

    private func request<T: Decodable & Sendable>(_ body: CoachRequest, as: T.Type) async throws -> T {
        let user = account.userId
        let data = try CoachAPI.encode(body)
        let token = try await account.token()
        do {
            let result = try await api.call("functions/v1/ai-coach", token: token, body: data, as: T.self)
            guard account.userId == user else { throw CancellationError() }
            return result
        } catch let error as CoachFailure where error.status == 401 {
            let refreshed = try await account.token(force: true)
            let result = try await api.call("functions/v1/ai-coach", token: refreshed, body: data, as: T.self)
            guard account.userId == user else { throw CancellationError() }
            return result
        }
    }
    func load() async {
        guard account.userId != nil, !busy, !sending else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            apply(try await request(CoachRequest(action: "bootstrap", conversationId: conversationId), as: CoachSnapshot.self))
            await loadPacks()
        } catch is CancellationError {} catch { message = error.localizedDescription }
    }
    private func apply(_ result: CoachSnapshot) {
        snapshot = result; conversationId = result.conversationId
        if let turn = result.turns.first(where: { $0.status == "pending" }) {
            retry = CoachPending(id: turn.id, conversationId: turn.conversationId, question: turn.question, context: turn.context)
        } else if let retry, result.turns.contains(where: { $0.id == retry.id && $0.status != "pending" }) { self.retry = nil }
    }
    func consent(_ accepted: Bool) async {
        guard !busy, !sending else { return }
        busy = true; message = nil
        defer { busy = false }
        do { apply(try await request(CoachRequest(action: "consent", conversationId: conversationId, accepted: accepted), as: CoachSnapshot.self)) }
        catch { message = error.localizedDescription }
    }
    func send(_ text: String, context: String) async {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend, !question.isEmpty, question.utf16.count <= 1600 else { return }
        let pending = CoachPending(id: UUID().uuidString.lowercased(), conversationId: conversationId ?? UUID().uuidString.lowercased(), question: question, context: context)
        retry = pending
        await submit(pending)
    }
    func retryReply() async {
        guard let retry, !sending, !busy else { return }
        await submit(retry)
    }
    private func submit(_ pending: CoachPending) async {
        sending = true; message = nil
        defer { sending = false }
        do {
            let result = try await request(CoachRequest.chat(pending), as: CoachSnapshot.self)
            apply(result)
            if let turn = result.turns.first(where: { $0.id == pending.id }) {
                if turn.status == "complete" { retry = nil }
                else if turn.status == "failed" { retry = nil; message = "No reply was saved, and the reserved credit was returned. You can send your question again." }
                else { message = "Coach is still preparing your reply. Refresh in a moment." }
            }
        } catch is CancellationError {} catch let error as CoachFailure {
            message = error.message
            if let code = error.code, ["no_credits","consent_required","coach_not_ready","provider_unavailable","rate_limit","daily_limit","invalid_request","request_conflict","request_deleted","purchase_verification_unavailable"].contains(code) { retry = nil }
        } catch { message = error.localizedDescription }
    }
    func newConversation() {
        guard !sending, retry == nil, wallet?.pending != true else { message = "Wait for the current reply before starting another conversation."; return }
        conversationId = UUID().uuidString.lowercased()
        snapshot = nil
        Task { await load() }
    }
    func openConversation(_ id: String) async {
        guard !sending, retry == nil else { return }
        conversationId = id
        await load()
    }
    func deleteConversation(_ id: String) async {
        guard !busy, !sending else { return }
        busy = true; message = nil
        defer { busy = false }
        do { apply(try await request(CoachRequest(action: "delete_conversation", conversationId: id), as: CoachSnapshot.self)) }
        catch { message = error.localizedDescription }
    }
    func signOut() async {
        guard !purchasing else { return }
        do { try await account.signOut(); clear() }
        catch { message = error.localizedDescription }
    }
    func deleteAccount() async {
        guard !busy, !sending, !purchasing else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            let result = try await request(CoachRequest(action: "delete_account"), as: CoachDeleted.self)
            if result.deleted { try account.clear(); clear() }
        } catch { message = error.localizedDescription }
    }
    func resetPrivateState() { clear() }
    private func clear() {
        snapshot = nil; conversationId = nil; retry = nil; packages = []; message = nil
    }
    func loadPacks() async {
        packages = []
        guard snapshot?.packsAvailable == true, !PlusPurchaseStore.isTestStore else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            packages = (offerings.offering(identifier: "coach_credits")?.availablePackages ?? [])
                .filter { ["coach_credits_50", "coach_credits_150"].contains($0.storeProduct.productIdentifier) }
                .sorted { $0.storeProduct.price < $1.storeProduct.price }
        } catch { message = "Credit packs couldn’t be loaded. Your monthly free replies are still yours." }
    }
    func purchase(_ package: Package, plus: PlusPurchaseStore) async {
        guard !purchasing, !sending, !busy, let user = account.userId, snapshot?.packsAvailable == true else { return }
        purchasing = true; message = nil
        defer { purchasing = false }
        do {
            let old = wallet?.purchased ?? 0
            guard try await plus.purchaseCredits(package, userId: user) else { return }
            apply(try await request(CoachRequest(action: "sync", conversationId: conversationId), as: CoachSnapshot.self))
            message = (wallet?.purchased ?? 0) > old ? "Your verified credits are ready." : "Purchase received. Credits are awaiting verification—don’t purchase again. Refresh your wallet shortly."
        } catch {
            let code = (error as NSError).code
            if code == ErrorCode.purchaseCancelledError.rawValue { return }
            message = code == ErrorCode.paymentPendingError.rawValue ? "Awaiting payment approval. Credits appear after verification; don’t purchase again." : "We couldn’t complete or verify this purchase. Refresh your wallet before trying another purchase."
        }
    }
    func workoutContext(_ repository: TrainingRepository) -> String {
        guard let workout = repository.selectedWorkout else { return "" }
        let steps = (workout.warmup + workout.main + workout.cooldown).prefix(16)
            .map { "\($0.title): \($0.targetText(units: repository.preferences.units))" }.joined(separator: "; ")
        let text = "Workout: \(workout.title). Purpose: \(workout.purpose). Level: \(workout.level.rawValue). Time: \(workout.timeBudget) minutes. Rounds: \(workout.rounds). Steps: \(steps)"
        return String(decoding: text.utf16.prefix(2300), as: UTF16.self)
    }
}
