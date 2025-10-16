import Foundation

struct AIChatMessage: Identifiable, Equatable {
    enum Role: String, Equatable {
        case user
        case assistant

        init(apiValue: String) {
            switch apiValue.lowercased() {
            case "user":
                self = .user
            default:
                self = .assistant
            }
        }

        var apiValue: String {
            rawValue
        }
    }

    let id: UUID
    let role: Role
    let content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
