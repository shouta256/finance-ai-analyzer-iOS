import AuthenticationServices
import CryptoKit
import Foundation
import os
import UIKit

@MainActor
protocol AuthService {
    func signIn() async throws -> AuthSession
}

enum AuthServiceError: Error, LocalizedError {
    case unableToConstructAuthorizeURL
    case missingAuthorizationCode
    case cancelled
    case stateMismatch

    var errorDescription: String? {
        switch self {
        case .unableToConstructAuthorizeURL: return "Unable to construct the sign-in URL."
        case .missingAuthorizationCode: return "We could not retrieve the authorization code. Please try again."
        case .cancelled: return "Sign-in was cancelled."
        case .stateMismatch: return "State verification failed. Please try again."
        }
    }
}

@MainActor
final class CognitoAuthService: NSObject, AuthService {
    private let configuration: AppConfiguration
    private let apiClient: ApiClient
    private var webAuthSession: ASWebAuthenticationSession?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Safepocket", category: "Auth")

    init(configuration: AppConfiguration, apiClient: ApiClient) {
        self.configuration = configuration
        self.apiClient = apiClient
        super.init()
    }

    func signIn() async throws -> AuthSession {
        let codeVerifier = makeCodeVerifier()
        let codeChallenge = makeCodeChallenge(from: codeVerifier)
        let state = makeState()
        let authorizeURL = try makeAuthorizeURL(codeChallenge: codeChallenge, state: state)
        logger.debug("Starting Cognito sign-in flow.")
        let callbackURL = try await startSession(authorizeURL: authorizeURL)
        logger.debug("Received callback URL from Cognito.")
        let (authorizationCode, returnedState) = try extractAuthorizationCodeAndState(from: callbackURL)
        guard returnedState == state else { throw AuthServiceError.stateMismatch }
        logger.debug("State verified. Exchanging authorization code with backend.")
        let session = try await apiClient.exchangeAuthCode(authorizationCode, codeVerifier: codeVerifier, redirectUri: configuration.cognitoRedirectURI.absoluteString)
        let userId = session.userId ?? "unknown"
        logger.notice("Login succeeded. userId: \(userId, privacy: .private(mask: .hash)), displayName: \(session.userDisplayName, privacy: .public)")
        return session
    }

    private func makeAuthorizeURL(codeChallenge: String, state: String) throws -> URL {
        var components = URLComponents(url: configuration.cognitoDomain.appending(path: "oauth2/authorize"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.cognitoClientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: configuration.cognitoRedirectURI.absoluteString),
            URLQueryItem(name: "scope", value: configuration.cognitoScopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = components?.url else { throw AuthServiceError.unableToConstructAuthorizeURL }
        return url
    }

    private func startSession(authorizeURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizeURL,
                callbackURLScheme: configuration.cognitoRedirectURI.scheme
            ) { [weak self] callbackURL, error in
                guard let self else { return }
                self.webAuthSession = nil

                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: AuthServiceError.cancelled)
                    return
                }
                if let error { continuation.resume(throwing: error); return }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthServiceError.missingAuthorizationCode)
                    return
                }
                self.logger.debug("ASWebAuthenticationSession finished.")
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = configuration.prefersEphemeralWebAuthSession
            self.webAuthSession = session
            if !session.start() { continuation.resume(throwing: AuthServiceError.unableToConstructAuthorizeURL) }
        }
    }

    private func extractAuthorizationCodeAndState(from url: URL) throws -> (String, String?) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AuthServiceError.missingAuthorizationCode
        }
        let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        let state = components.queryItems?.first(where: { $0.name == "state" })?.value
        guard let code, !code.isEmpty else { throw AuthServiceError.missingAuthorizationCode }
        return (code, state)
    }

    private func makeCodeVerifier() -> String { makeRandomURLSafeString(length: Int.random(in: 43...128)) }
    private func makeState() -> String { makeRandomURLSafeString(length: 32) }

    private func makeRandomURLSafeString(length: Int) -> String {
        // Keep it conservative (alphanumerics only) to avoid any edge-case issues with intermediaries.
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var generator = SystemRandomNumberGenerator()
        let result = (0..<length).map { _ in characters[Int.random(in: 0..<characters.count, using: &generator)] }
        return String(result)
    }

    private func makeCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let digest = SHA256.hash(data: data)
        return Data(digest).base64URLEncodedString()
    }
}

extension CognitoAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return ASPresentationAnchor() }
        return window
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
