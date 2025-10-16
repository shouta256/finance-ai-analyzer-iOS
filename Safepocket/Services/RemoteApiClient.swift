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
        // Note: バックエンドはcamelCaseを期待しているため、keyEncodingStrategyは設定しない
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

        let url = configuration.baseURL.appending(path: "api/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(UUID().uuidString, forHTTPHeaderField: configuration.traceHeaderName)
        
        let payload = Payload(
            grantType: "authorization_code",
            code: code,
            redirectUri: redirectUri,
            codeVerifier: codeVerifier
        )
        let body = try encoder.encode(payload)
        request.httpBody = body
        
        #if DEBUG
        if let jsonString = String(data: body, encoding: .utf8) {
            print("[HTTP] POST /api/auth/token body: \(jsonString)")
        }
        #endif

        let data = try await perform(request: request, expectingStatus: 200)
        let response = try decoder.decode(Response.self, from: data)
        let expiresAt = Date().addingTimeInterval(response.expiresIn)
    #if DEBUG
    print("[HTTP] /api/auth/token success. Access token received (hidden). expiresIn=\(response.expiresIn)s")
    #endif
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

        let url = configuration.baseURL.appending(path: "api/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(UUID().uuidString, forHTTPHeaderField: configuration.traceHeaderName)
        
        let payload = Payload(
            grantType: "refresh_token",
            refreshToken: refreshToken
        )
        let body = try encoder.encode(payload)
        request.httpBody = body
        
        #if DEBUG
        if let jsonString = String(data: body, encoding: .utf8) {
            print("[HTTP] POST /api/auth/token (refresh) body: \(jsonString)")
        }
        #endif

        let data = try await perform(request: request, expectingStatus: 200)
        let response = try decoder.decode(Response.self, from: data)
        let expiresAt = Date().addingTimeInterval(response.expiresIn)
        #if DEBUG
        print("[HTTP] /api/auth/token (refresh) success. New access token received. expiresIn=\(response.expiresIn)s")
        #endif
        return AuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken, // 新しいリフレッシュトークンがなければ既存のものを保持
            idToken: response.idToken,
            expiresAt: expiresAt,
            userId: response.userId,
            tokenType: response.tokenType
        )
    }

    func fetchAccounts(accessToken: String) async throws -> [Account] {
        let url = configuration.baseURL.appending(path: "api/accounts")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue(UUID().uuidString, forHTTPHeaderField: configuration.traceHeaderName)

        let data = try await perform(request: request, expectingStatus: 200)
        
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[HTTP] GET /api/accounts raw response: \(jsonString)")
        } else {
            print("[HTTP] GET /api/accounts - unable to convert response to string")
        }
        #endif
        
        do {
            let response = try decoder.decode(AccountsListResponse.self, from: data)
            
            #if DEBUG
            print("[HTTP] Decoded \(response.accounts.count) accounts from AccountsListResponse")
            #endif
            
            return response.accounts
        } catch {
            #if DEBUG
            print("[HTTP] Failed to decode AccountsListResponse: \(error)")
            #endif
            throw error
        }
    }

    private func perform(request: URLRequest, expectingStatus status: Int) async throws -> Data {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ApiError.unknown
            }

            #if DEBUG
            print("[HTTP] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "-") status=\(httpResponse.statusCode)")
            #endif

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
            #if DEBUG
            print(message)
            #endif
        } else if let body = String(data: data, encoding: .utf8), !body.isEmpty {
            let message = "[HTTP \(statusCode)] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "-")\nraw body: \(body)"
            logger.error("\(message, privacy: .public)")
            #if DEBUG
            print(message)
            #endif
        } else {
            let message = "[HTTP \(statusCode)] \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "-") (no readable body)"
            logger.error("\(message, privacy: .public)")
            #if DEBUG
            print(message)
            #endif
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
