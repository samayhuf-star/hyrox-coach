import Foundation

struct CoachUser: Codable, Sendable {
    let id: String
    let email: String?
}
struct CoachSession: Codable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Double?
    var expiresIn: Int?
    var user: CoachUser
}
struct CoachWallet: Decodable, Sendable {
    let free: Int
    let purchased: Int
    let resetAt: Date
    let consented: Bool
    let pending: Bool
    var total: Int { free + max(0, purchased) }
}
struct CoachTurn: Decodable, Identifiable, Sendable {
    let id: String
    let conversationId: String
    let question: String
    let answer: String?
    let context: String
    let status: String
    let createdAt: Date
}
struct CoachConversation: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let updatedAt: Date
}
struct CoachSnapshot: Decodable, Sendable {
    let wallet: CoachWallet
    let conversationId: String
    let turns: [CoachTurn]
    let conversations: [CoachConversation]
    let aiReady: Bool
    let packsAvailable: Bool
    let enabledProducts: [String]
}
struct CoachRequest: Encodable, Sendable {
    var action: String
    var conversationId: String?
    var requestId: String?
    var question: String?
    var context: String?
    var accepted: Bool?
}
struct CoachPending: Sendable {
    let id: String
    let conversationId: String
    let question: String
    let context: String
}
struct CoachDeleted: Decodable, Sendable { let deleted: Bool }

struct CoachFailure: Error, LocalizedError, Sendable {
    let status: Int
    let message: String
    let code: String?
    var errorDescription: String? { message }
}

extension CoachRequest {
    static func chat(_ pending: CoachPending) -> CoachRequest {
        CoachRequest(action: "chat", conversationId: pending.conversationId, requestId: pending.id,
                     question: pending.question, context: pending.context)
    }
}
