import Foundation
import os

extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    static let withoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

struct RemoteApiClient: ApiClient {
    private let configuration: AppConfiguration
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Safepocket", category: "RemoteApiClient")

    private func endpoint(_ path: String) -> URL {
        configuration.baseURL.appending(path: path)
    }

    init(configuration: AppConfiguration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession

        let decoder = JSONDecoder()
        // ISO8601 with fractional seconds support
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
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // The backend expects camelCase keys, so we keep the default encoding strategy.
        self.encoder = encoder
    }

    func exchangeAuthCode(_ code: String, codeVerifier: String, redirectUri: String) async throws -> AuthSession {
        struct Payload: Encodable {
            let grantType: String
            let code: String
            let redirectUri: String
            let codeVerifier: String
        }
        struct Response: Decodable {
            let accessToken: String
            let idToken: String?
            let refreshToken: String?
            let expiresIn: TimeInterval
            let tokenType: String
            let userId: String?
        }

        let url = endpoint("auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(UUID().uuidString, forHTTPHeaderField: configuration.traceHeaderName)
        request.addValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        logger.debug("POST /auth/token with authorization_code grant.")
        
        let payload = Payload(
            grantType: "authorization_code",
            code: code,
            redirectUri: redirectUri,
            codeVerifier: codeVerifier
        )
        let body = try encoder.encode(payload)
        request.httpBody = body
        
        let data = try await perform(request: request, expectingStatus: 200)
        let response = try decoder.decode(Response.self, from: data)
        let expiresAt = Date().addingTimeInterval(response.expiresIn)
        logger.debug("Received tokens from /auth/token (authorization_code). expiresIn: \(response.expiresIn, privacy: .public)s")
        return AuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            idToken: response.idToken,
            expiresAt: expiresAt,
            userId: response.userId,
            tokenType: response.tokenType
        )
    }

    func refreshAccessToken(_ refreshToken: String) async throws -> AuthSession {
        struct Payload: Encodable {
            let grantType: String
            let refreshToken: String
        }
        struct Response: Decodable {
            let accessToken: String
            let idToken: String?
            let refreshToken: String?
            let expiresIn: TimeInterval
            let tokenType: String
            let userId: String?
        }

        let url = endpoint("auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(UUID().uuidString, forHTTPHeaderField: configuration.traceHeaderName)
        request.addValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        logger.debug("POST /auth/token with refresh_token grant.")
        
        let payload = Payload(
            grantType: "refresh_token",
            refreshToken: refreshToken
        )
        let body = try encoder.encode(payload)
        request.httpBody = body
        
        let data = try await perform(request: request, expectingStatus: 200)
        let response = try decoder.decode(Response.self, from: data)
        let expiresAt = Date().addingTimeInterval(response.expiresIn)
        logger.debug("Received tokens from /auth/token (refresh_token). expiresIn: \(response.expiresIn, privacy: .public)s")
        return AuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken, // Keep the previous refresh token when the response omits a new one
            idToken: response.idToken,
            expiresAt: expiresAt,
            userId: response.userId,
            tokenType: response.tokenType
        )
    }

    func fetchAccounts(accessToken: String) async throws -> [Account] {
        let url = endpoint("accounts")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(UUID().uuidString, forHTTPHeaderField: configuration.traceHeaderName)

        let data = try await perform(request: request, expectingStatus: 200)

        do {
            let response = try decoder.decode(AccountsListResponse.self, from: data)
            logger.debug("Fetched \(response.accounts.count, privacy: .public) accounts from /accounts.")
            return response.accounts
        } catch {
            logger.error("Failed to decode AccountsListResponse: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func perform(request: URLRequest, expectingStatus status: Int) async throws -> Data {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ApiError.unknown
            }

            logger.debug("\(request.httpMethod ?? "") \(request.url?.absoluteString ?? "-") status=\(httpResponse.statusCode, privacy: .public)")

            guard httpResponse.statusCode == status else {
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
        } catch let error as URLError {
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw ApiError.unreachable
            }
            throw ApiError.unknown
        } catch {
            throw ApiError.unknown
        }
    }

    private func logApiError(statusCode: Int, request: URLRequest, data: Data) {
        let decoder = JSONDecoder()

        if let errorResponse = try? decoder.decode(ApiErrorResponse.self, from: data) {
            let message = "[HTTP \(statusCode)] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "-" )\ncode: \(errorResponse.error.code)\nmessage: \(errorResponse.error.message)\ntraceId: \(errorResponse.traceId)"
            logger.error("\(message, privacy: .public)")
        } else if let body = String(data: data, encoding: .utf8), !body.isEmpty {
            let message = "[HTTP \(statusCode)] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "-")\nraw body: \(body)"
            logger.error("\(message, privacy: .public)")
        } else {
            let message = "[HTTP \(statusCode)] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "-") (no readable body)"
            logger.error("\(message, privacy: .public)")
        }
    }
}

private struct ApiErrorResponse: Decodable {
    struct Detail: Decodable {
        let code: String
        let message: String
    }

    let error: Detail
    let traceId: String
}
