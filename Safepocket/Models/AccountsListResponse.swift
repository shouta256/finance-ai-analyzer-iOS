import Foundation

struct AccountsListResponse: Codable {
    let currency: String
    let totalBalance: Decimal
    let accounts: [Account]
    let traceId: String?

    private enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance
        case accounts
        case traceId
    }

    init(currency: String, totalBalance: Decimal, accounts: [Account], traceId: String?) {
        self.currency = currency
        self.totalBalance = totalBalance
        self.accounts = accounts
        self.traceId = traceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let accounts = try container.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        let decodedBalance = try container.decodeIfPresent(Decimal.self, forKey: .totalBalance)

        let totalBalance: Decimal
        if let decodedBalance {
            totalBalance = decodedBalance
        } else {
            totalBalance = accounts.reduce(Decimal.zero) { $0 + $1.balance }
        }

        let currency = try container.decodeIfPresent(String.self, forKey: .currency)
            ?? accounts.first?.currency
            ?? Locale.current.currency?.identifier
            ?? "USD"

        let traceId = try container.decodeIfPresent(String.self, forKey: .traceId)

        self.init(
            currency: currency,
            totalBalance: totalBalance,
            accounts: accounts,
            traceId: traceId
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currency, forKey: .currency)
        try container.encode(totalBalance, forKey: .totalBalance)
        try container.encode(accounts, forKey: .accounts)
        try container.encodeIfPresent(traceId, forKey: .traceId)
    }
}
