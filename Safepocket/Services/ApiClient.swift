import Foundation

enum ApiError: Error, LocalizedError {
    case invalidCredentials
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case decodingFailed
    case unreachable
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "The credentials provided were rejected."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You do not have permission to perform that action."
        case .notFound:
            return "The requested resource could not be found."
        case .rateLimited:
            return "You’re sending requests too quickly. Please retry in a moment."
        case .decodingFailed:
            return "The response from the server was not understood."
        case .unreachable:
            return "The Safepocket service is currently unreachable. Check your connection."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
}

protocol ApiClient {
    func exchangeAuthCode(_ code: String, codeVerifier: String, redirectUri: String) async throws -> AuthSession
    func refreshAccessToken(_ refreshToken: String) async throws -> AuthSession
    func fetchAccounts(accessToken: String) async throws -> [Account]
}
