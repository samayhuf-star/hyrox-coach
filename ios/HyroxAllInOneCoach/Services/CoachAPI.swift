import Foundation
import Security

struct CoachAPI: Sendable {
    static let base = URL(string: "https://bmproxvtagkaomdyijao.supabase.co")!
    static let publicKey = "sb_publishable_DlOGjGZlj8UePaNo4RMFRQ_2UcP8sIH"
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 100
        return URLSession(configuration: configuration)
    }()
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date"))
        }
        return decoder
    }
    func call<T: Decodable & Sendable>(_ path: String, token: String? = nil,
                                      body: Data? = nil, method: String = "POST", as: T.Type) async throws -> T {
        let parts = path.split(separator: "?", maxSplits: 1).map(String.init)
        var components = URLComponents(url: Self.base.appending(path: parts[0]), resolvingAgainstBaseURL: false)!
        if parts.count == 2 { components.percentEncodedQuery = parts[1] }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue(Self.publicKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = body
        do {
            let (data, response) = try await Self.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw CoachFailure(status: 0, message: "No response. Please try again.", code: nil) }
            guard (200..<300).contains(http.statusCode) else {
                let fields = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                let text = fields?["error"] as? String ?? fields?["msg"] as? String ?? fields?["message"] as? String
                throw CoachFailure(status: http.statusCode, message: text ?? "Coach is unavailable. Please try again.", code: fields?["code"] as? String)
            }
            if T.self == CoachEmpty.self { return CoachEmpty() as! T }
            return try Self.decoder().decode(T.self, from: data)
        } catch let error as URLError {
            let text = error.code == .notConnectedToInternet ? "You’re offline. Your workouts still work; Coach needs an internet connection." : "The connection was interrupted. Refresh or retry to recover your saved reply without paying twice."
            throw CoachFailure(status: 0, message: text, code: "connection")
        }
    }
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(value)
    }
    static func json(_ values: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: values) }
}
struct CoachEmpty: Decodable, Sendable {}

enum CoachKeychain {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "hybrid.coach.auth", kSecAttrAccount as String: "session"]
    }
    static func read() throws -> Data? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CoachFailure(status: 0, message: "Your saved sign-in could not be opened.", code: nil) }
        return value as? Data
    }
    static func save(_ data: Data) throws {
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound { status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil) }
        guard status == errSecSuccess else { throw CoachFailure(status: 0, message: "We couldn’t save your sign-in securely. Please try again.", code: nil) }
    }
    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CoachFailure(status: 0, message: "Couldn’t clear your saved sign-in. Please try again.", code: nil) }
    }
}
