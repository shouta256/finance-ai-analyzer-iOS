import SwiftUI

@main
struct SafepocketApp: App {
    @StateObject private var sessionController: AppSessionController
    private let apiClient: ApiClient
    private let authService: AuthService
    private let dashboardService: any DashboardService
    private let aiService: any AIService

    init() {
        let configuration = AppConfiguration.shared
        let apiClient = RemoteApiClient(configuration: configuration)
        let authService = CognitoAuthService(configuration: configuration, apiClient: apiClient)
        let dashboardService: any DashboardService = DemoDashboardService()
        let aiService: any AIService = RemoteAIService(configuration: configuration)
        let sessionStore: SessionStore = KeychainSessionStore()

        self.apiClient = apiClient
        self.authService = authService
        self.dashboardService = dashboardService
        self.aiService = aiService
        _sessionController = StateObject(wrappedValue: AppSessionController(sessionStore: sessionStore))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                apiClient: apiClient,
                authService: authService,
                dashboardService: dashboardService,
                aiService: aiService
            )
                .environmentObject(sessionController)
        }
    }
}
