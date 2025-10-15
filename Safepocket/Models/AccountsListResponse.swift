import Foundation

struct AccountsListResponse: Codable {
    let currency: String
    let totalBalance: Decimal
    let accounts: [Account]
    let traceId: String?
}
