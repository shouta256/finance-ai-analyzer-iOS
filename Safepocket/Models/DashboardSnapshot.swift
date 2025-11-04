import Foundation

struct DashboardSnapshot: Equatable {
    struct Summary: Equatable {
        let income: Decimal
        let expenses: Decimal
        let net: Decimal
        let currencyCode: String
    }

    struct CategorySpend: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let amount: Decimal
        /// Percentage is expressed as 0.0 - 1.0
        let percentage: Double
    }

    struct MerchantActivity: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let amount: Decimal
        let transactionCount: Int
    }

    struct MonthlyHighlight: Equatable {
        let title: String
        let message: String
        let generatedForPeriod: String
    }

    struct AnomalyAlert: Identifiable, Equatable {
        let id = UUID()
        let merchant: String
        let amount: Decimal
        let differenceFromTypical: Decimal
        let budgetImpactPercentage: Double
        let detectedAt: Date
        let currencyCode: String
    }

    struct RecentTransaction: Identifiable, Equatable {
        enum Status: String, Equatable {
            case posted = "Posted"
            case pending = "Pending"
        }

        let id = UUID()
        let merchant: String
        let category: String
        let amount: Decimal
        let status: Status
        let postedAt: Date
        let currencyCode: String
    }

    let summary: Summary
    let categories: [CategorySpend]
    let merchants: [MerchantActivity]
    let monthlyHighlight: MonthlyHighlight?
    let anomalyAlerts: [AnomalyAlert]
    let recentTransactions: [RecentTransaction]
    let netTrend: [NetTrendPoint]

    struct NetTrendPoint: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let net: Decimal

        var netValue: Double {
            NSDecimalNumber(decimal: net).doubleValue
        }
    }
}

extension DashboardSnapshot {
    static let sample: DashboardSnapshot = {
        let currency = "USD"

        return DashboardSnapshot(
            summary: Summary(
                income: 824,
                expenses: -1_942.26,
                net: -1_118.26,
                currencyCode: currency
            ),
            categories: [
                CategorySpend(name: "Uncategorized", amount: -1_118.26, percentage: 1.0)
            ],
            merchants: [
                MerchantActivity(name: "Washburn Sou", amount: -1_181.52, transactionCount: 2),
                MerchantActivity(name: "Zelle Instant Pmt", amount: -800, transactionCount: 2),
                MerchantActivity(name: "Walmart", amount: -309.52, transactionCount: 6),
                MerchantActivity(name: "Asian Market", amount: -91.54, transactionCount: 2)
            ],
            monthlyHighlight: MonthlyHighlight(
                title: "AI Monthly Highlight",
                message: "Click \"Generate AI Summary\" to create an AI highlight for 2025-10.",
                generatedForPeriod: "2025-10"
            ),
            anomalyAlerts: [
                AnomalyAlert(
                    merchant: "Washburn Sou",
                    amount: -590.76,
                    differenceFromTypical: 566.89,
                    budgetImpactPercentage: 0.304,
                    detectedAt: Date(timeIntervalSince1970: 1_756_647_600),
                    currencyCode: currency
                ),
                AnomalyAlert(
                    merchant: "Washburn Sou",
                    amount: -590.76,
                    differenceFromTypical: 566.89,
                    budgetImpactPercentage: 0.304,
                    detectedAt: Date(timeIntervalSince1970: 1_756_647_600),
                    currencyCode: currency
                )
            ],
            recentTransactions: [
                RecentTransaction(
                    merchant: "Walmart",
                    category: "Uncategorized",
                    amount: -53.95,
                    status: .posted,
                    postedAt: Date(timeIntervalSince1970: 1_756_733_200),
                    currencyCode: currency
                ),
                RecentTransaction(
                    merchant: "Asian Market",
                    category: "Uncategorized",
                    amount: -45.77,
                    status: .posted,
                    postedAt: Date(timeIntervalSince1970: 1_756_646_400),
                    currencyCode: currency
                ),
                RecentTransaction(
                    merchant: "Kwik Shop",
                    category: "Uncategorized",
                    amount: -11.45,
                    status: .posted,
                    postedAt: Date(timeIntervalSince1970: 1_756_646_400),
                    currencyCode: currency
                ),
                RecentTransaction(
                    merchant: "Monthly Maintenance Fee Waived",
                    category: "Uncategorized",
                    amount: 12,
                    status: .posted,
                    postedAt: Date(timeIntervalSince1970: 1_756_560_000),
                    currencyCode: currency
                ),
                RecentTransaction(
                    merchant: "CVS",
                    category: "Uncategorized",
                    amount: -19.53,
                    status: .posted,
                    postedAt: Date(timeIntervalSince1970: 1_756_560_000),
                    currencyCode: currency
                )
            ],
            netTrend: [
                NetTrendPoint(date: Date(timeIntervalSince1970: 1_756_560_000), net: -120),
                NetTrendPoint(date: Date(timeIntervalSince1970: 1_756_646_400), net: -320.45),
                NetTrendPoint(date: Date(timeIntervalSince1970: 1_756_732_800), net: -190.32),
                NetTrendPoint(date: Date(timeIntervalSince1970: 1_756_819_200), net: -40.12),
                NetTrendPoint(date: Date(timeIntervalSince1970: 1_756_905_600), net: -118.89),
                NetTrendPoint(date: Date(timeIntervalSince1970: 1_756_992_000), net: 45.22)
            ]
        )
    }()
}
