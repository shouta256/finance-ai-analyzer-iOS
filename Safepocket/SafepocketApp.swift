import SwiftUI

@main
struct SafepocketApp: App {
    @StateObject private var sessionController: AppSessionController
    private let apiClient: ApiClient
    private let authService: AuthService

    init() {
        let configuration = AppConfiguration.shared
        let apiClient = RemoteApiClient(configuration: configuration)
        let authService = CognitoAuthService(configuration: configuration, apiClient: apiClient)
        let sessionStore: SessionStore = KeychainSessionStore()

        self.apiClient = apiClient
        self.authService = authService
        _sessionController = StateObject(wrappedValue: AppSessionController(sessionStore: sessionStore))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(apiClient: apiClient, authService: authService)
                .environmentObject(sessionController)
        }
    }
}
