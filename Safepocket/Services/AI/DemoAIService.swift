import Foundation

struct DemoAIService: AIService {
    private let latency: UInt64 = 220_000_000
    private static var storedConversations: [UUID: [AIChatMessage]] = [:]

    func generateSummary(for prompt: String, session: AuthSession) async throws -> AISummary {
        try await Task.sleep(nanoseconds: latency)
        let response = """
        2025年10月の支出で一番多く使っているのは、**Washburn Sou**で、合計で**$1,181.52**（約118,152セント）です。次に多いのは、**Walmart**で、合計**$309.52**（約30,952セント）です。
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
                    content: "こんにちは！Safepocketの支出データから知りたいことはありますか？"
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

        if normalized.contains("dining") || normalized.contains("食") {
            response = "先月の外食・フード関連の支出は合計で$482.12でした。主な内訳はWalmartが$180.44、Washburn Souが$122.35です。"
        } else if normalized.contains("budget") || normalized.contains("予算") {
            response = "10月は食料品が予算比で+18%、趣味が+5%です。交通は-4%なので余裕があります。"
        } else {
            response = "ご質問ありがとうございます。2025年10月の取引では、Washburn Souへの支出がもっとも高く、次いでWalmartが続きます。さらに詳しく知りたいカテゴリがあれば教えてください。"
        }

        let id = conversationId ?? UUID()

        var history = DemoAIService.storedConversations[id] ?? [
            AIChatMessage(
                id: UUID(),
                role: .assistant,
                content: "こんにちは！Safepocketの支出データから知りたいことはありますか？"
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
