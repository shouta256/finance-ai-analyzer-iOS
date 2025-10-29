import Foundation

protocol AIService {
    func generateSummary(for prompt: String, month: Date, regenerate: Bool, session: AuthSession) async throws -> AISummary
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

extension AIService {
    func generateSummary(for prompt: String, session: AuthSession) async throws -> AISummary {
        try await generateSummary(for: prompt, month: Date(), regenerate: false, session: session)
    }

    func generateSummary(for prompt: String, month: Date, session: AuthSession) async throws -> AISummary {
        try await generateSummary(for: prompt, month: month, regenerate: false, session: session)
    }
}
