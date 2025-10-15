import Foundation

struct AppConfiguration {
    let baseURL: URL
    let cognitoDomain: URL
    let cognitoClientId: String
    let cognitoRedirectURI: URL
    let cognitoScopes: [String]
    let prefersEphemeralWebAuthSession: Bool
    let traceHeaderName: String = "X-Request-Trace"

    static let shared: AppConfiguration = {
    let info = Bundle.main.infoDictionary ?? [:]
    #if DEBUG
    let defaultBase = "http://localhost:8081"
    #else
    let defaultBase = "https://api.shota256.me"
    #endif
    let baseURLString = (info["ApiBaseURL"] as? String) ?? defaultBase

        guard let baseURL = URL(string: baseURLString) else {
            preconditionFailure("Invalid API base URL")
        }

    // Allow overriding via Info.plist for quick environment/client switching
        let domainString = (info["CognitoDomain"] as? String) ?? "https://shota256.auth.us-east-1.amazoncognito.com"
        guard let cognitoDomain = URL(string: domainString) else {
            preconditionFailure("Invalid Cognito domain URL")
        }

        // Native OAuth via custom scheme
        let redirectUriString = (info["CognitoRedirectURI"] as? String) ?? "safepocket://auth/callback"
        guard let redirectURI = URL(string: redirectUriString) else {
            preconditionFailure("Invalid redirect URI")
        }

        let clientId = (info["CognitoClientId"] as? String) ?? "5ge4c1b382ft2v71rvip0rrhqv"
        let scopeString = (info["CognitoScopes"] as? String) ?? "openid email phone"
        let scopes = scopeString.split(separator: " ").map { String($0) }.filter { !$0.isEmpty }

        return AppConfiguration(
            baseURL: baseURL,
            cognitoDomain: cognitoDomain,
            cognitoClientId: clientId,
            cognitoRedirectURI: redirectURI,
            cognitoScopes: scopes,
            prefersEphemeralWebAuthSession: false // set true if you want ephemeral cookies
        )
    }()
}
