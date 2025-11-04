import Foundation

struct AnalyticsSummaryEnvelope: Decodable {
    let summary: Summary
    let categories: [Category]
    let merchants: [Merchant]
    let monthlyHighlight: Highlight?
    let anomalyAlerts: [Anomaly]
    let recentTransactions: [Transaction]
    let aiHighlights: AIHighlights?
    let traceId: String?

    private enum CodingKeys: String, CodingKey {
        case summary
        case categories
        case merchants
        case monthlyHighlight
        case anomalyAlerts
        case recentTransactions
        case aiHighlights
        case aiSummary
        case traceId
        case data
        case dashboard
        case payload
        case totals
        case byCategory
        case topMerchants
        case anomalies
        case aiHighlight
        case month
    }

    init(from decoder: Decoder) throws {
        let rootContainer = try decoder.container(keyedBy: CodingKeys.self)
        traceId = try rootContainer.decodeIfPresent(String.self, forKey: .traceId)

        if rootContainer.contains(.totals) {
            let month = try rootContainer.decodeIfPresent(String.self, forKey: .month)
            let totals = try rootContainer.decode(NewTotals.self, forKey: .totals)
            let summaryValue = totals.toSummary()
            let currencyCode = summaryValue.currencyCode

            let newCategories = try rootContainer.decodeIfPresent([NewCategory].self, forKey: .byCategory) ?? []
            let categoryValue = newCategories.map { $0.toCategory() }

            let newMerchants = try rootContainer.decodeIfPresent([NewMerchant].self, forKey: .topMerchants) ?? []
            let merchantValue = newMerchants.map { $0.toMerchant() }

            let newAnomalies = try rootContainer.decodeIfPresent([NewAnomaly].self, forKey: .anomalies) ?? []
            let anomalyValue = newAnomalies.map { $0.toAnomaly(currency: currencyCode) }

            let highlight = try rootContainer.decodeIfPresent(NewAIHighlight.self, forKey: .aiHighlight)

            summary = summaryValue
            categories = categoryValue
            merchants = merchantValue
            monthlyHighlight = highlight?.snapshot(for: month)
            anomalyAlerts = anomalyValue
            recentTransactions = []
            aiHighlights = highlight?.toAIHighlights()
            return
        }

        let payloadContainer = try AnalyticsSummaryEnvelope.resolvePayloadContainer(from: rootContainer)

        let summaryValue = try payloadContainer.decode(Summary.self, forKey: .summary)
        let categoryValue = try payloadContainer.decodeIfPresent([Category].self, forKey: .categories) ?? []
        let merchantValue = try payloadContainer.decodeIfPresent([Merchant].self, forKey: .merchants) ?? []
        let highlightValue = try payloadContainer.decodeIfPresent(Highlight.self, forKey: .monthlyHighlight)
        let anomalyValue = try payloadContainer.decodeIfPresent([Anomaly].self, forKey: .anomalyAlerts) ?? []
        let transactionValue = try payloadContainer.decodeIfPresent([Transaction].self, forKey: .recentTransactions) ?? []

        summary = summaryValue
        categories = categoryValue
        merchants = merchantValue
        monthlyHighlight = highlightValue
        anomalyAlerts = anomalyValue
        recentTransactions = transactionValue

        if let highlights = try payloadContainer.decodeIfPresent(AIHighlights.self, forKey: .aiHighlights) {
            aiHighlights = highlights
        } else {
            aiHighlights = try payloadContainer.decodeIfPresent(AIHighlights.self, forKey: .aiSummary)
        }
    }

    private static func resolvePayloadContainer(from container: KeyedDecodingContainer<CodingKeys>) throws -> KeyedDecodingContainer<CodingKeys> {
        if container.contains(.summary) {
            return container
        }

        if container.contains(.data) {
            let nested = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
            return try resolvePayloadContainer(from: nested)
        }

        if container.contains(.dashboard) {
            let nested = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .dashboard)
            return try resolvePayloadContainer(from: nested)
        }

        if container.contains(.payload) {
            let nested = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .payload)
            return try resolvePayloadContainer(from: nested)
        }

        throw DecodingError.keyNotFound(
            CodingKeys.summary,
            DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Unable to find summary payload in analytics response."
            )
        )
    }

    var dashboardSnapshot: DashboardSnapshot {
        DashboardSnapshot(
            summary: summary.snapshot,
            categories: categories.map(\.snapshot),
            merchants: merchants.map(\.snapshot),
            monthlyHighlight: monthlyHighlight?.snapshot,
            anomalyAlerts: anomalyAlerts.map(\.snapshot),
            recentTransactions: recentTransactions.map(\.snapshot),
            netTrend: []
        )
    }

    func aiSummary(fallbackPrompt prompt: String) -> AISummary? {
        guard let highlights = aiHighlights else { return nil }
        return AISummary(
            prompt: highlights.prompt ?? prompt,
            response: highlights.text,
            generatedAt: highlights.generatedAt
        )
    }
}

extension AnalyticsSummaryEnvelope {
    struct Summary: Decodable {
        let income: Decimal
        let expenses: Decimal
        let net: Decimal
        let currencyCode: String

        private enum CodingKeys: String, CodingKey {
            case income
            case expenses
            case net
            case currencyCode
            case currency
        }

        init(income: Decimal, expenses: Decimal, net: Decimal, currencyCode: String) {
            self.income = income
            self.expenses = expenses
            self.net = net
            self.currencyCode = currencyCode
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            income = try container.decode(Decimal.self, forKey: .income)
            expenses = try container.decode(Decimal.self, forKey: .expenses)
            net = try container.decode(Decimal.self, forKey: .net)
            currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
                ?? container.decodeIfPresent(String.self, forKey: .currency)
                ?? Locale.current.currency?.identifier
                ?? "USD"
        }

        var snapshot: DashboardSnapshot.Summary {
            DashboardSnapshot.Summary(
                income: income,
                expenses: expenses,
                net: net,
                currencyCode: currencyCode
            )
        }
    }

    struct NewTotals: Decodable {
        let income: Decimal
        let expense: Decimal
        let net: Decimal

        private enum CodingKeys: String, CodingKey {
            case income
            case expense
            case net
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            income = try container.decodeDecimal(forKey: .income)
            expense = try container.decodeDecimal(forKey: .expense)
            net = try container.decodeDecimal(forKey: .net)
        }

        func toSummary() -> Summary {
            Summary(
                income: income,
                expenses: expense,
                net: net,
                currencyCode: Locale.current.currency?.identifier ?? "USD"
            )
        }
    }

    struct NewCategory: Decodable {
        let category: String
        let amount: Decimal
        let percentage: Double

        private enum CodingKeys: String, CodingKey {
            case category
            case amount
            case percentage
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            category = try container.decode(String.self, forKey: .category)
            amount = try container.decodeDecimal(forKey: .amount)
            percentage = (try container.decodeIfPresent(Double.self, forKey: .percentage) ?? 0) / 100
        }

        func toCategory() -> Category {
            Category(
                name: category,
                amount: amount,
                percentage: percentage
            )
        }
    }

    struct NewMerchant: Decodable {
        let merchant: String
        let amount: Decimal
        let transactionCount: Int

        private enum CodingKeys: String, CodingKey {
            case merchant
            case amount
            case transactionCount
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            merchant = try container.decode(String.self, forKey: .merchant)
            amount = try container.decodeDecimal(forKey: .amount)
            transactionCount = try container.decodeIfPresent(Int.self, forKey: .transactionCount) ?? 0
        }

        func toMerchant() -> Merchant {
            Merchant(
                name: merchant,
                amount: amount,
                transactionCount: transactionCount
            )
        }
    }

    struct NewAnomaly: Decodable {
        let transactionId: String?
        let method: String?
        let amount: Decimal
        let deltaAmount: Decimal
        let budgetImpactPercent: Double
        let occurredAt: Date
        let merchantName: String
        let commentary: String?

        private enum CodingKeys: String, CodingKey {
            case transactionId
            case method
            case amount
            case deltaAmount
            case budgetImpactPercent
            case occurredAt
            case merchantName
            case commentary
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            transactionId = try container.decodeIfPresent(String.self, forKey: .transactionId)
            method = try container.decodeIfPresent(String.self, forKey: .method)
            amount = try container.decodeDecimal(forKey: .amount)
            deltaAmount = try container.decodeDecimal(forKey: .deltaAmount)
            budgetImpactPercent = (try container.decodeIfPresent(Double.self, forKey: .budgetImpactPercent) ?? 0) / 100
            occurredAt = try container.decode(Date.self, forKey: .occurredAt)
            merchantName = try container.decode(String.self, forKey: .merchantName)
            commentary = try container.decodeIfPresent(String.self, forKey: .commentary)
        }

        func toAnomaly(currency: String) -> Anomaly {
            Anomaly(
                merchant: merchantName,
                amount: amount,
                differenceFromTypical: deltaAmount,
                budgetImpactPercentage: budgetImpactPercent,
                detectedAt: occurredAt,
                currencyCode: currency
            )
        }
    }

    struct NewAIHighlight: Decodable {
        let title: String
        let summary: String
        let recommendations: [String]

        private enum CodingKeys: String, CodingKey {
            case title
            case summary
            case recommendations
        }

        func snapshot(for month: String?) -> Highlight {
            let messageBody: String
            if recommendations.isEmpty {
                messageBody = summary
            } else {
                let bullets = recommendations.map { "• \($0)" }.joined(separator: "\n")
                messageBody = summary + "\n\n" + bullets
            }

            return Highlight(
                title: title,
                message: messageBody,
                generatedForPeriod: month ?? ""
            )
        }

        func toAIHighlights() -> AIHighlights {
            AIHighlights(
                prompt: nil,
                text: formattedText,
                generatedAt: Date()
            )
        }

        private var formattedText: String {
            if recommendations.isEmpty {
                return summary
            }
            let bullets = recommendations.map { "• \($0)" }.joined(separator: "\n")
            return summary + "\n\n" + bullets
        }
    }

    struct Category: Decodable {
        let name: String
        let amount: Decimal
        let percentage: Double

        private enum CodingKeys: String, CodingKey {
            case name
            case amount
            case percentage
            case share
        }

        init(name: String, amount: Decimal, percentage: Double) {
            self.name = name
            self.amount = amount
            self.percentage = percentage
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            amount = try container.decode(Decimal.self, forKey: .amount)
            percentage = try container.decodeIfPresent(Double.self, forKey: .percentage)
                ?? container.decodeIfPresent(Double.self, forKey: .share)
                ?? 0
        }

        var snapshot: DashboardSnapshot.CategorySpend {
            DashboardSnapshot.CategorySpend(
                name: name,
                amount: amount,
                percentage: percentage
            )
        }
    }

    struct Merchant: Decodable {
        let name: String
        let amount: Decimal
        let transactionCount: Int

        private enum CodingKeys: String, CodingKey {
            case name
            case amount
            case transactionCount
            case transactions
            case count
        }

        init(name: String, amount: Decimal, transactionCount: Int) {
            self.name = name
            self.amount = amount
            self.transactionCount = transactionCount
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            amount = try container.decode(Decimal.self, forKey: .amount)
            transactionCount = try container.decodeIfPresent(Int.self, forKey: .transactionCount)
                ?? container.decodeIfPresent(Int.self, forKey: .transactions)
                ?? container.decodeIfPresent(Int.self, forKey: .count)
                ?? 0
        }

        var snapshot: DashboardSnapshot.MerchantActivity {
            DashboardSnapshot.MerchantActivity(
                name: name,
                amount: amount,
                transactionCount: transactionCount
            )
        }
    }

    struct Highlight: Decodable {
        let title: String
        let message: String
        let generatedForPeriod: String

        private enum CodingKeys: String, CodingKey {
            case title
            case message
            case generatedForPeriod
            case period
        }

        init(title: String, message: String, generatedForPeriod: String) {
            self.title = title
            self.message = message
            self.generatedForPeriod = generatedForPeriod
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decode(String.self, forKey: .title)
            message = try container.decode(String.self, forKey: .message)
            generatedForPeriod = try container.decodeIfPresent(String.self, forKey: .generatedForPeriod)
                ?? container.decodeIfPresent(String.self, forKey: .period)
                ?? ""
        }

        var snapshot: DashboardSnapshot.MonthlyHighlight {
            DashboardSnapshot.MonthlyHighlight(
                title: title,
                message: message,
                generatedForPeriod: generatedForPeriod
            )
        }
    }

    struct Anomaly: Decodable {
        let merchant: String
        let amount: Decimal
        let differenceFromTypical: Decimal
        let budgetImpactPercentage: Double
        let detectedAt: Date
        let currencyCode: String

        private enum CodingKeys: String, CodingKey {
            case merchant
            case amount
            case differenceFromTypical
            case budgetImpactPercentage
            case detectedAt
            case currencyCode
            case currency
        }

        init(
            merchant: String,
            amount: Decimal,
            differenceFromTypical: Decimal,
            budgetImpactPercentage: Double,
            detectedAt: Date,
            currencyCode: String
        ) {
            self.merchant = merchant
            self.amount = amount
            self.differenceFromTypical = differenceFromTypical
            self.budgetImpactPercentage = budgetImpactPercentage
            self.detectedAt = detectedAt
            self.currencyCode = currencyCode
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            merchant = try container.decode(String.self, forKey: .merchant)
            amount = try container.decode(Decimal.self, forKey: .amount)
            differenceFromTypical = try container.decode(Decimal.self, forKey: .differenceFromTypical)
            budgetImpactPercentage = try container.decode(Double.self, forKey: .budgetImpactPercentage)
            detectedAt = try container.decode(Date.self, forKey: .detectedAt)
            currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
                ?? container.decodeIfPresent(String.self, forKey: .currency)
                ?? Locale.current.currency?.identifier
                ?? "USD"
        }

        var snapshot: DashboardSnapshot.AnomalyAlert {
            DashboardSnapshot.AnomalyAlert(
                merchant: merchant,
                amount: amount,
                differenceFromTypical: differenceFromTypical,
                budgetImpactPercentage: budgetImpactPercentage,
                detectedAt: detectedAt,
                currencyCode: currencyCode
            )
        }
    }

    struct Transaction: Decodable {
        let merchant: String
        let category: String?
        let amount: Decimal
        let status: String
        let postedAt: Date
        let currencyCode: String

        private enum CodingKeys: String, CodingKey {
            case merchant
            case category
            case categories
            case amount
            case status
            case transactionStatus
            case postedAt
            case date
            case authorizedDate
            case currencyCode
            case currency
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            merchant = try container.decodeIfPresent(String.self, forKey: .merchant)
                ?? container.decodeIfPresent(String.self, forKey: .category)
                ?? "Unknown Merchant"
            if let explicitCategory = try container.decodeIfPresent(String.self, forKey: .category) {
                category = explicitCategory
            } else if let categories = try container.decodeIfPresent([String].self, forKey: .categories) {
                category = categories.first
            } else {
                category = nil
            }

            if let decimalAmount = try? container.decode(Decimal.self, forKey: .amount) {
                amount = decimalAmount
            } else if let stringAmount = try? container.decode(String.self, forKey: .amount),
                      let decimal = Decimal(string: stringAmount) {
                amount = decimal
            } else if let doubleAmount = try? container.decode(Double.self, forKey: .amount) {
                amount = Decimal(doubleAmount)
            } else {
                amount = 0
            }

            status = try container.decodeIfPresent(String.self, forKey: .status)
                ?? container.decodeIfPresent(String.self, forKey: .transactionStatus)
                ?? "posted"

            if let explicitDate = try container.decodeIfPresent(Date.self, forKey: .postedAt) {
                postedAt = explicitDate
            } else if let alternativeDate = try container.decodeIfPresent(Date.self, forKey: .date) {
                postedAt = alternativeDate
            } else if let authorizedDate = try container.decodeIfPresent(Date.self, forKey: .authorizedDate) {
                postedAt = authorizedDate
            } else {
                postedAt = Date()
            }

            currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
                ?? container.decodeIfPresent(String.self, forKey: .currency)
                ?? Locale.current.currency?.identifier
                ?? "USD"
        }

        var snapshot: DashboardSnapshot.RecentTransaction {
            DashboardSnapshot.RecentTransaction(
                merchant: merchant,
                category: category ?? "Uncategorized",
                amount: amount,
                status: DashboardSnapshot.RecentTransaction.Status(apiValue: status),
                postedAt: postedAt,
                currencyCode: currencyCode
            )
        }
    }

    struct AIHighlights: Decodable {
        let prompt: String?
        let text: String
        let generatedAt: Date

        private enum CodingKeys: String, CodingKey {
            case prompt
            case text
            case response
            case body
            case generatedAt
            case createdAt
            case updatedAt
        }

        init(prompt: String?, text: String, generatedAt: Date) {
            self.prompt = prompt
            self.text = text
            self.generatedAt = generatedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            prompt = try container.decodeIfPresent(String.self, forKey: .prompt)

            if let value = try container.decodeIfPresent(String.self, forKey: .text) {
                text = value
            } else if let value = try container.decodeIfPresent(String.self, forKey: .response) {
                text = value
            } else if let value = try container.decodeIfPresent(String.self, forKey: .body) {
                text = value
            } else {
                throw DecodingError.keyNotFound(
                    CodingKeys.text,
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Missing text field for AI summary."
                    )
                )
            }

            if let generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) {
                self.generatedAt = generatedAt
            } else if let updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) {
                self.generatedAt = updatedAt
            } else if let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) {
                self.generatedAt = createdAt
            } else {
                throw DecodingError.keyNotFound(
                    CodingKeys.generatedAt,
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Missing generation timestamp for AI summary."
                    )
                )
            }
        }
    }
}

extension DashboardSnapshot.RecentTransaction.Status {
    init(apiValue: String) {
        switch apiValue.lowercased() {
        case "pending":
            self = .pending
        default:
            self = .posted
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeDecimal(forKey key: Key) throws -> Decimal {
        if let value = try decodeIfPresent(Decimal.self, forKey: key) {
            return value
        }

        if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
            return Decimal(doubleValue)
        }

        if let stringValue = try decodeIfPresent(String.self, forKey: key),
           let decimal = Decimal(string: stringValue) {
            return decimal
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Unable to decode decimal for key \(key.stringValue)"
        )
    }
}
