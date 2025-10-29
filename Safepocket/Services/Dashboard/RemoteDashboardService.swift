import Foundation
import os

struct RemoteDashboardService: DashboardService {
    private let configuration: AppConfiguration
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let logger: Logger
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private func endpoint(_ path: String) -> URL {
        configuration.baseURL.appending(path: path)
    }

    private func summaryURL(for month: Date) -> URL {
        var components = URLComponents(url: endpoint("analytics/summary"), resolvingAgainstBaseURL: false)
        let monthValue = Self.monthFormatter.string(from: month)
        var queryItems = [URLQueryItem(name: "month", value: monthValue)]
        if let existing = components?.queryItems {
            queryItems.append(contentsOf: existing)
        }
        components?.queryItems = queryItems
        return components?.url ?? endpoint("analytics/summary")
    }

    init(configuration: AppConfiguration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "Safepocket",
            category: "RemoteDashboardService"
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: dateString) {
                return date
            }

            if let date = ISO8601DateFormatter.withoutFractionalSeconds.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(dateString)"
            )
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func fetchDashboard(for session: AuthSession, month: Date) async throws -> DashboardSnapshot {
        var request = URLRequest(url: summaryURL(for: month))
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(UUID().uuidString, forHTTPHeaderField: configuration.traceHeaderName)

        let data = try await perform(request: request, expectedStatus: 200)
        let response = try decoder.decode(AnalyticsSummaryEnvelope.self, from: data)
        var snapshot = response.dashboardSnapshot

        if snapshot.recentTransactions.isEmpty {
            let recent = try await fetchRecentTransactions(
                session: session,
                month: month,
                limit: 12
            )

            snapshot = DashboardSnapshot(
                summary: snapshot.summary,
                categories: snapshot.categories,
                merchants: snapshot.merchants,
                monthlyHighlight: snapshot.monthlyHighlight,
                anomalyAlerts: snapshot.anomalyAlerts,
                recentTransactions: recent
            )
        }

        return snapshot
    }

    private func perform(request: URLRequest, expectedStatus: Int) async throws -> Data {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ApiError.unknown
            }

            guard httpResponse.statusCode == expectedStatus else {
                logApiError(
                    statusCode: httpResponse.statusCode,
                    request: request,
                    data: data
                )

                switch httpResponse.statusCode {
                case 400:
                    throw ApiError.invalidCredentials
                case 401:
                    throw ApiError.unauthorized
                case 403:
                    throw ApiError.forbidden
                case 404:
                    throw ApiError.notFound
                case 429:
                    throw ApiError.rateLimited
                case 500...599:
                    throw ApiError.unreachable
                default:
                    throw ApiError.unknown
                }
            }

            return data
        } catch let error as ApiError {
            throw error
        } catch {
            logger.error("Dashboard request failed: \(error.localizedDescription, privacy: .public)")
            throw ApiError.unknown
        }
    }

    private func logApiError(statusCode: Int, request: URLRequest, data: Data) {
        guard
            let body = String(data: data, encoding: .utf8),
            !body.isEmpty
        else {
            logger.error("[HTTP \(statusCode)] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "-") without body")
            return
        }

        logger.error("[HTTP \(statusCode)] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "-"): \(body, privacy: .public)")
    }

    private func fetchRecentTransactions(
        session: AuthSession,
        month: Date,
        limit: Int
    ) async throws -> [DashboardSnapshot.RecentTransaction] {
        var components = URLComponents(url: endpoint("transactions"), resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "month", value: Self.monthFormatter.string(from: month)),
            URLQueryItem(name: "pageSize", value: String(limit))
        ]
        if let existing = components?.queryItems {
            queryItems.append(contentsOf: existing)
        }
        components?.queryItems = queryItems

        var request = URLRequest(url: components?.url ?? endpoint("transactions"))
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(UUID().uuidString, forHTTPHeaderField: configuration.traceHeaderName)

        let data = try await perform(request: request, expectedStatus: 200)
        let response = try decoder.decode(TransactionsEnvelope.self, from: data)
        return response.transactions.map(\.snapshot)
    }
}

private struct TransactionsEnvelope: Decodable {
    let transactions: [Transaction]

    private enum CodingKeys: String, CodingKey {
        case transactions
        case items
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let direct = try container.decodeIfPresent([Transaction].self, forKey: .transactions) {
            transactions = direct
        } else if let items = try container.decodeIfPresent([Transaction].self, forKey: .items) {
            transactions = items
        } else if let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data),
                  let nested = try dataContainer.decodeIfPresent([Transaction].self, forKey: .transactions) {
            transactions = nested
        } else {
            transactions = []
        }
    }

    struct Transaction: Decodable {
        let id: String?
        let merchant: String?
        let name: String?
        let description: String?
        let category: String?
        let categories: [String]?
        let amount: Decimal
        let status: String
        let postedAt: Date
        let currencyCode: String

        private enum CodingKeys: String, CodingKey {
            case id
            case merchant
            case name
            case description
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
            id = try container.decodeIfPresent(String.self, forKey: .id)
            merchant = try container.decodeIfPresent(String.self, forKey: .merchant)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            description = try container.decodeIfPresent(String.self, forKey: .description)
            category = try container.decodeIfPresent(String.self, forKey: .category)
            categories = try container.decodeIfPresent([String].self, forKey: .categories)

            if let decimal = try? container.decode(Decimal.self, forKey: .amount) {
                amount = decimal
            } else if let doubleValue = try? container.decode(Double.self, forKey: .amount) {
                amount = Decimal(doubleValue)
            } else if let stringValue = try? container.decode(String.self, forKey: .amount),
                      let decimal = Decimal(string: stringValue) {
                amount = decimal
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .amount,
                    in: container,
                    debugDescription: "Unable to decode amount from transaction payload."
                )
            }

            if let status = try container.decodeIfPresent(String.self, forKey: .status) {
                self.status = status
            } else if let status = try container.decodeIfPresent(String.self, forKey: .transactionStatus) {
                self.status = status
            } else {
                self.status = "posted"
            }

            if let postedAt = try container.decodeIfPresent(Date.self, forKey: .postedAt) {
                self.postedAt = postedAt
            } else if let postedAt = try container.decodeIfPresent(Date.self, forKey: .date) {
                self.postedAt = postedAt
            } else if let postedAt = try container.decodeIfPresent(Date.self, forKey: .authorizedDate) {
                self.postedAt = postedAt
            } else {
                self.postedAt = Date()
            }

            if let code = try container.decodeIfPresent(String.self, forKey: .currencyCode) {
                currencyCode = code
            } else if let code = try container.decodeIfPresent(String.self, forKey: .currency) {
                currencyCode = code
            } else {
                currencyCode = Locale.current.currency?.identifier ?? "USD"
            }
        }

        var snapshot: DashboardSnapshot.RecentTransaction {
            DashboardSnapshot.RecentTransaction(
                merchant: merchantName,
                category: resolvedCategory,
                amount: amount,
                status: DashboardSnapshot.RecentTransaction.Status(apiValue: status),
                postedAt: postedAt,
                currencyCode: currencyCode
            )
        }

        private var merchantName: String {
            merchant ?? name ?? description ?? "Unknown Merchant"
        }

        private var resolvedCategory: String {
            if let category, !category.isEmpty {
                return category
            }
            if let first = categories?.first, !first.isEmpty {
                return first
            }
            return "Uncategorized"
        }
    }
}
