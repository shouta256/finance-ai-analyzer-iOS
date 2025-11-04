#if DEBUG
import Foundation

struct MockApiClient: ApiClient {
    private let latency: UInt64 = 300_000_000 // 0.3s

    func exchangeAuthCode(_ code: String, codeVerifier: String, redirectUri: String) async throws -> AuthSession {
        try await Task.sleep(nanoseconds: latency)
        guard !code.isEmpty, !codeVerifier.isEmpty else {
            throw ApiError.invalidCredentials
        }
        return AuthSession(
            accessToken: "mock-access-token-\(UUID().uuidString)",
            refreshToken: "mock-refresh-token-\(UUID().uuidString)",
            idToken: nil,
            expiresAt: Date().addingTimeInterval(60 * 60), // 1時間
            userId: "mock-user-\(UUID().uuidString)",
            tokenType: "Bearer"
        )
    }

    func refreshAccessToken(_ refreshToken: String) async throws -> AuthSession {
        try await Task.sleep(nanoseconds: latency)
        guard refreshToken.hasPrefix("mock-refresh-token") else {
            throw ApiError.unauthorized
        }
        return AuthSession(
            accessToken: "mock-access-token-refreshed-\(UUID().uuidString)",
            refreshToken: refreshToken, // 同じリフレッシュトークンを返す
            idToken: nil,
            expiresAt: Date().addingTimeInterval(60 * 60),
            userId: "mock-user-\(UUID().uuidString)",
            tokenType: "Bearer"
        )
    }

    func fetchAccounts(accessToken: String) async throws -> [Account] {
        guard accessToken.hasPrefix("mock-access-token") else {
            throw ApiError.unauthorized
        }

        try await Task.sleep(nanoseconds: latency)
        return Account.previewAccounts
    }
}
#endif
