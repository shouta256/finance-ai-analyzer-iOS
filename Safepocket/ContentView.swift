import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionController: AppSessionController
    private let apiClient: ApiClient
    private let authService: AuthService
    private let dashboardService: any DashboardService
    private let aiService: any AIService

    init(
        apiClient: ApiClient,
        authService: AuthService,
        dashboardService: any DashboardService = DemoDashboardService(),
        aiService: any AIService = DemoAIService()
    ) {
        self.apiClient = apiClient
        self.authService = authService
        self.dashboardService = dashboardService
        self.aiService = aiService
    }

    var body: some View {
        Group {
            if sessionController.session == nil || sessionController.session?.isExpired == true {
                NavigationStack {
                    LoginView(
                        viewModel: LoginViewModel(
                            authService: authService,
                            sessionController: sessionController
                        )
                    )
                }
            } else {
                AuthenticatedHomeView(
                    apiClient: apiClient,
                    dashboardService: dashboardService,
                    aiService: aiService
                )
                .environmentObject(sessionController)
            }
        }
        .animation(.easeInOut, value: sessionController.session != nil)
    }
}

#if DEBUG
#Preview {
    let sessionController = AppSessionController(sessionStore: InMemorySessionStore())
    return ContentView(
        apiClient: MockApiClient(),
        authService: PreviewAuthService(),
        dashboardService: DemoDashboardService(),
        aiService: DemoAIService()
    )
        .environmentObject(sessionController)
}
#endif

@MainActor
private final class PreviewAuthService: AuthService {
    func signIn() async throws -> AuthSession {
        AuthSession(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            idToken: nil,
            expiresAt: Date().addingTimeInterval(3600),
            userId: "preview-user-id",
            tokenType: "Bearer"
        )
    }
}

private struct AuthenticatedHomeView: View {
    @EnvironmentObject private var sessionController: AppSessionController
    private let apiClient: ApiClient
    private let dashboardService: any DashboardService
    private let aiService: any AIService

    init(
        apiClient: ApiClient,
        dashboardService: any DashboardService,
        aiService: any AIService
    ) {
        self.apiClient = apiClient
        self.dashboardService = dashboardService
        self.aiService = aiService
    }

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(
                    viewModel: DashboardViewModel(
                        dashboardService: dashboardService,
                        sessionController: sessionController
                    ),
                    summaryViewModel: AISummaryViewModel(
                        prompt: "Where am I spending the most?",
                        aiService: aiService,
                        sessionController: sessionController
                    )
                )
            }
            .tabItem {
                Label("Overview", systemImage: "chart.pie.fill")
            }

            NavigationStack {
                AccountListView(
                    viewModel: AccountListViewModel(
                        apiClient: apiClient,
                        sessionController: sessionController
                    )
                )
            }
            .tabItem {
                Label("Accounts", systemImage: "creditcard.fill")
            }

            NavigationStack {
                AIChatView(
                    viewModel: AIChatViewModel(
                        aiService: aiService,
                        sessionController: sessionController
                    )
                )
            }
            .tabItem {
                Label("AI Chat", systemImage: "bubble.left.and.bubble.right.fill")
            }
        }
        .tint(.indigo)
    }
}
