import Foundation

protocol AIService {
    func generateSummary(for prompt: String, session: AuthSession) async throws -> AISummary
    func fetchConversation(
        session: AuthSession,
        conversationId: UUID?
    ) async throws -> AIChatConversation
    func sendMessage(
        _ message: String,
        conversationId: UUID?,
        truncateFromMessageId: UUID?,
        session: AuthSession
    ) async throws -> AIChatConversation
}
