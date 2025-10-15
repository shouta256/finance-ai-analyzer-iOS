import Foundation

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let expiresAt: Date
    let userId: String?
    let tokenType: String

    var isExpired: Bool {
        Date() >= expiresAt
    }
    
    var userDisplayName: String {
        userId ?? "Safepocket Member"
    }
}
