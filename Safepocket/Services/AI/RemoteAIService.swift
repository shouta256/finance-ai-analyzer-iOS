import Foundation
import os

final class RemoteAIService: AIService {
    private let configuration: AppConfiguration
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger: Logger
    private var conversationId: UUID?
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

    private func summaryURL(for month: Date, generateAi: Bool) -> URL {
        var components = URLComponents(url: endpoint("analytics/summary"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "month", value: Self.monthFormatter.string(from: month))
        ]

        if generateAi {
            queryItems.append(URLQueryItem(name: "generateAi", value: "true"))
        }

        components?.queryItems = queryItems
        return components?.url ?? endpoint("analytics/summary")
    }

    init(configuration: AppConfiguration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "Safepocket",
            category: "RemoteAIService"
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatters = [
                ISO8601DateFormatter.withFractionalSeconds,
                ISO8601DateFormatter.withoutFractionalSeconds
            ]

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(dateString)"
            )
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func generateSummary(for prompt: String, month: Date, regenerate: Bool, session: AuthSession) async throws -> AISummary {
        let url = summaryURL(for: month, generateAi: regenerate)
        let request = authorizedRequest(url: url, method: "GET", accessToken: session.accessToken)
        let data = try await perform(request: request, expectedStatus: 200)
        let envelope = try decoder.decode(AnalyticsSummaryEnvelope.self, from: data)

        if let summary = envelope.aiSummary(fallbackPrompt: prompt) {
            return summary
        }

        if !regenerate {
            return try await generateSummary(
                for: prompt,
                month: month,
                regenerate: true,
                session: session
            )
        }

        throw ApiError.decodingFailed
    }

    func fetchConversation(
        session: AuthSession,
        conversationId: UUID?
    ) async throws -> AIChatConversation {
        let url = chatURL(conversationId: conversationId ?? self.conversationId)
        let request = authorizedRequest(url: url, method: "GET", accessToken: session.accessToken)

        let data = try await perform(request: request, expectedStatus: 200)
        let response = try decoder.decode(ChatResponse.self, from: data)
        let conversation = try parseConversation(from: response)
        self.conversationId = conversation.id
        return conversation
    }

    func sendMessage(
        _ message: String,
        conversationId: UUID?,
        truncateFromMessageId: UUID?,
        session: AuthSession
    ) async throws -> AIChatConversation {
        struct Payload: Encodable {
            let conversationId: UUID?
            let message: String
            let truncateFromMessageId: UUID?
        }

        let url = endpoint("ai/chat")
        var request = authorizedRequest(url: url, method: "POST", accessToken: session.accessToken)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try encoder.encode(
            Payload(
                conversationId: conversationId ?? self.conversationId,
                message: message,
                truncateFromMessageId: truncateFromMessageId
            )
        )

        let data = try await perform(request: request, expectedStatus: 200)
        let response = try decoder.decode(ChatResponse.self, from: data)
        let conversation = try parseConversation(from: response)
        self.conversationId = conversation.id
        return conversation
    }

    private func chatURL(conversationId: UUID?) -> URL {
        guard let conversationId else {
            return endpoint("ai/chat")
        }

        var components = URLComponents(
            url: endpoint("ai/chat"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "conversationId", value: conversationId.uuidString)]
        return components?.url ?? endpoint("ai/chat")
    }

    private func parseConversation(from response: ChatResponse) throws -> AIChatConversation {
        guard let conversationId = UUID(uuidString: response.conversationId) else {
            throw ApiError.decodingFailed
        }

        let messages = response.messages
            .map(AIChatMessage.init(_:))
            .sorted(by: { $0.createdAt < $1.createdAt })

        return AIChatConversation(id: conversationId, messages: messages)
    }

    private func authorizedRequest(url: URL, method: String, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(UUID().uuidString, forHTTPHeaderField: configuration.traceHeaderName)
        return request
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
            logger.error("Remote AI request failed: \(error.localizedDescription, privacy: .public)")
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
}

private extension RemoteAIService {
    struct ChatResponse: Decodable {
        let conversationId: String
        let messages: [Message]
        let traceId: String?
    }

    struct Message: Decodable {
        let id: UUID?
        let role: String
        let content: String
        let createdAt: Date?
    }

}

private extension AIChatMessage {
    init(_ message: RemoteAIService.Message) {
        self.init(
            id: message.id ?? UUID(),
            role: AIChatMessage.Role(apiValue: message.role),
            content: message.content,
            createdAt: message.createdAt ?? Date()
        )
    }
}
