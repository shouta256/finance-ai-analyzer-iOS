import Foundation

struct AIChatConversation: Equatable {
    let id: UUID
    let messages: [AIChatMessage]
}
