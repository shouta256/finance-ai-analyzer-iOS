import Foundation

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published private(set) var messages: [AIChatMessage] = []
    @Published private(set) var isLoadingHistory: Bool = false
    @Published private(set) var isSending: Bool = false
    @Published var inputText: String = ""
    @Published var errorMessage: String?
    @Published private(set) var editingMessage: AIChatMessage?

    private let aiService: any AIService
    private let sessionController: AppSessionController
    private var conversationId: UUID?

    init(
        aiService: any AIService,
        sessionController: AppSessionController
    ) {
        self.aiService = aiService
        self.sessionController = sessionController
    }

    func loadInitialMessages() async {
        guard !isLoadingHistory else { return }

        guard let session = sessionController.session, !session.isExpired else {
            messages = []
            errorMessage = ApiError.unauthorized.localizedDescription
            return
        }

        isLoadingHistory = true
        errorMessage = nil
        defer { isLoadingHistory = false }

        do {
            let conversation = try await aiService.fetchConversation(
                session: session,
                conversationId: conversationId
            )
            conversationId = conversation.id
            messages = conversation.messages
            editingMessage = nil
        } catch let error as ApiError {
            errorMessage = error.localizedDescription
            messages = []
            conversationId = nil
            editingMessage = nil
        } catch {
            errorMessage = ApiError.unknown.localizedDescription
            messages = []
            conversationId = nil
            editingMessage = nil
        }
    }

    func sendCurrentMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isSending else { return }

        guard let session = sessionController.session, !session.isExpired else {
            errorMessage = ApiError.unauthorized.localizedDescription
            return
        }

        let previousMessages = messages
        let previousEditing = editingMessage

        if let editingMessage,
           let index = messages.firstIndex(where: { $0.id == editingMessage.id }) {
            messages.removeSubrange(index...)
        }

        isSending = true
        errorMessage = nil

        let userMessage = AIChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        inputText = ""

        do {
            let conversation = try await aiService.sendMessage(
                trimmed,
                conversationId: conversationId,
                truncateFromMessageId: previousEditing?.id,
                session: session
            )
            conversationId = conversation.id
            messages = conversation.messages
            editingMessage = nil
        } catch let error as ApiError {
            errorMessage = error.localizedDescription
            messages = previousMessages
            inputText = trimmed
            editingMessage = previousEditing
        } catch {
            errorMessage = ApiError.unknown.localizedDescription
            messages = previousMessages
            inputText = trimmed
            editingMessage = previousEditing
        }

        isSending = false
    }

    func retry() async {
        await loadInitialMessages()
    }

    func beginEditing(message: AIChatMessage) {
        guard message.role == .user else { return }
        editingMessage = message
        inputText = message.content
    }

    func cancelEditing() {
        editingMessage = nil
    }
}
