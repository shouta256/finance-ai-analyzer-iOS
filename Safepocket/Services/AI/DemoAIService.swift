import Foundation

struct DemoAIService: AIService {
    private let latency: UInt64 = 220_000_000
    private static var storedConversations: [UUID: [AIChatMessage]] = [:]

    func generateSummary(for prompt: String, month: Date, regenerate: Bool, session: AuthSession) async throws -> AISummary {
        try await Task.sleep(nanoseconds: latency)
        let response = """
        In October 2025 you spent the most at **Washburn Sou** for a total of **$1,181.52**, followed by **Walmart** at **$309.52**.
        """
        return AISummary(
            prompt: prompt,
            response: response,
            generatedAt: Date()
        )
    }

    func fetchConversation(
        session: AuthSession,
        conversationId: UUID?
    ) async throws -> AIChatConversation {
        try await Task.sleep(nanoseconds: latency)
        let id = conversationId ?? UUID()

        if DemoAIService.storedConversations[id] == nil {
            DemoAIService.storedConversations[id] = [
                AIChatMessage(
                    id: UUID(),
                    role: .assistant,
                    content: "Hello! What would you like to explore in your Safepocket spending data?"
                )
            ]
        }

        return AIChatConversation(
            id: id,
            messages: DemoAIService.storedConversations[id] ?? []
        )
    }

    func sendMessage(
        _ message: String,
        conversationId: UUID?,
        truncateFromMessageId: UUID?,
        session: AuthSession
    ) async throws -> AIChatConversation {
        try await Task.sleep(nanoseconds: latency)

        let normalized = message.lowercased()
        let response: String

        if normalized.contains("dining") || normalized.contains("food") {
            response = "Dining and food spending last month totaled $482.12. Walmart accounted for $180.44 and Washburn Sou for $122.35."
        } else if normalized.contains("budget") {
            response = "In October, groceries ran 18% above budget while hobbies were 5% higher. Transportation was under budget by 4%, giving you some flexibility."
        } else {
            response = "Thanks for asking. In October 2025 your highest spend was at Washburn Sou, followed by Walmart. Let me know if you'd like to dive into a specific category."
        }

        let id = conversationId ?? UUID()

        var history = DemoAIService.storedConversations[id] ?? [
            AIChatMessage(
                id: UUID(),
                role: .assistant,
                content: "Hello! What would you like to explore in your Safepocket spending data?"
            )
        ]

        if let truncateFromMessageId,
           let index = history.firstIndex(where: { $0.id == truncateFromMessageId }) {
            history.removeSubrange(index...)
        }

        let user = AIChatMessage(id: UUID(), role: .user, content: message)
        let assistant = AIChatMessage(id: UUID(), role: .assistant, content: response)

        history.append(contentsOf: [user, assistant])
        DemoAIService.storedConversations[id] = history

        return AIChatConversation(id: id, messages: history)
    }
}
