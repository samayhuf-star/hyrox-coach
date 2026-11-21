import Foundation
import Observation

@MainActor @Observable
final class CoachAccount {
    private(set) var session: CoachSession?
    private(set) var busy = false
    private(set) var sentTo: String?
    private(set) var resendAfter: Date = .distantPast
    var message: String?
    @ObservationIgnored private var refreshTask: Task<CoachSession, Error>?
    private let api = CoachAPI()
    var userId: String? { session?.user.id.lowercased() }
    var email: String { session?.user.email ?? "Your Coach account" }

    init() {
        do {
            if let data = try CoachKeychain.read() { session = try JSONDecoder().decode(CoachSession.self, from: data) }
        } catch { message = "Your saved Coach sign-in couldn’t be opened. Sign in again; your online history is safe." }
    }
    func sendCode(email: String) async {
        guard !busy, Date.now >= resendAfter else { return }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.contains("@"), email.count <= 254 else { message = "Enter a valid email address."; return }
        busy = true; message = nil
        defer { busy = false }
        do {
            let body = try CoachAPI.json(["email": email, "create_user": true])
            _ = try await api.call("auth/v1/otp?redirect_to=hybridcoach%3A%2F%2Fauth%2Fcallback", body: body, as: CoachEmpty.self)
            sentTo = email
            resendAfter = Date.now.addingTimeInterval(60)
        } catch { message = error.localizedDescription }
    }
    func changeEmail() { sentTo = nil; message = nil }
    func verify(code: String) async {
        guard !busy, let email = sentTo else { return }
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (6...10).contains(code.count), code.allSatisfy(\.isNumber) else { message = "Enter the code from your email."; return }
        busy = true; message = nil
        defer { busy = false }
        do {
            let body = try CoachAPI.json(["email": email, "token": code, "type": "email"])
            let value = try await api.call("auth/v1/verify", body: body, as: CoachSession.self)
            try save(value)
            sentTo = nil
        } catch { message = error.localizedDescription }
    }
    func token(force: Bool = false) async throws -> String {
        guard let session else { throw CoachFailure(status: 401, message: "Please sign in to Coach.", code: nil) }
        if !force, (session.expiresAt ?? 0) > Date.now.timeIntervalSince1970 + 60 { return session.accessToken }
        if let refreshTask { return try await refreshTask.value.accessToken }
        let original = session.user.id
        let task = Task<CoachSession, Error> {
            let body = try CoachAPI.json(["refresh_token": session.refreshToken])
            return try await api.call("auth/v1/token?grant_type=refresh_token", body: body, as: CoachSession.self)
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let value = try await task.value
            guard self.session?.user.id == original else { throw CancellationError() }
            try save(value)
            return value.accessToken
        } catch let error as CoachFailure where [400,401].contains(error.status) {
            try? clear()
            throw CoachFailure(status: 401, message: "Your sign-in expired. Sign in again to recover your Coach credits and chats.", code: nil)
        }
    }
    func signOut() async throws {
        if let token = session?.accessToken {
            _ = try? await api.call("auth/v1/logout?scope=local", token: token, as: CoachEmpty.self)
        }
        try clear()
    }
    func clear() throws {
        try CoachKeychain.remove()
        refreshTask?.cancel(); refreshTask = nil
        session = nil; sentTo = nil; message = nil
    }
    private func save(_ value: CoachSession) throws {
        var value = value
        value.expiresAt = value.expiresAt ?? Date.now.timeIntervalSince1970 + Double(value.expiresIn ?? 3600)
        try CoachKeychain.save(JSONEncoder().encode(value))
        session = value
    }
    func openCallback(_ url: URL) async {
        guard url.scheme == "hybridcoach", url.host == "auth", url.path == "/callback", !busy, let expectedEmail = sentTo else { return }
        let values = URLComponents(string: "https://callback.invalid/?" + (url.fragment ?? url.query ?? ""))?.queryItems ?? []
        let fields = Dictionary(values.map { ($0.name,$0.value ?? "") }, uniquingKeysWith: { first,_ in first })
        guard let access = fields["access_token"], let refresh = fields["refresh_token"] else { message = "This sign-in link could not be verified. Request another email."; return }
        busy = true; defer { busy = false }
        do {
            let user = try await api.call("auth/v1/user", token: access, method: "GET", as: CoachUser.self)
            guard user.email?.lowercased() == expectedEmail else { throw CoachFailure(status: 401, message: "This link belongs to a different email.", code: nil) }
            try save(CoachSession(accessToken: access, refreshToken: refresh, expiresAt: nil, expiresIn: Int(fields["expires_in"] ?? "3600"), user: user))
            sentTo = nil
        } catch { message = "This sign-in link has expired. Request another email." }
    }
}
