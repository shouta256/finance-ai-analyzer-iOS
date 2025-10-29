import Foundation

struct Account: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let institution: String
    let type: String?
    let balance: Decimal
    let currency: String
    let createdAt: Date
    let lastTransactionAt: Date?
    let linkedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case institution
        case type
        case balance
        case currency
        case createdAt
        case lastTransactionAt
        case linkedAt
    }
}

extension Account {
    static let previewAccounts: [Account] = [
        Account(
            id: "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6",
            name: "Everyday Checking",
            institution: "Safepocket Bank",
            type: "checking",
            balance: Decimal(string: "1250.42")!,
            currency: "USD",
            createdAt: Date(),
            lastTransactionAt: Date(),
            linkedAt: Date()
        ),
        Account(
            id: "b2c3d4e5-f6g7-h8i9-j0k1-l2m3n4o5p6q7",
            name: "Savings Vault",
            institution: "Safepocket Bank",
            type: "savings",
            balance: Decimal(string: "8420.18")!,
            currency: "USD",
            createdAt: Date(),
            lastTransactionAt: Date(),
            linkedAt: Date()
        ),
        Account(
            id: "c3d4e5f6-g7h8-i9j0-k1l2-m3n4o5p6q7r8",
            name: "Rewards Card",
            institution: "Safepocket Card",
            type: "credit",
            balance: Decimal(string: "-240.67")!,
            currency: "USD",
            createdAt: Date(),
            lastTransactionAt: Date(),
            linkedAt: Date()
        )
    ]
}
