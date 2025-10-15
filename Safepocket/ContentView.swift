import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionController: AppSessionController
    private let apiClient: ApiClient
    private let authService: AuthService

    init(apiClient: ApiClient, authService: AuthService) {
        self.apiClient = apiClient
        self.authService = authService
    }

    var body: some View {
        NavigationStack {
            if sessionController.session == nil || sessionController.session?.isExpired == true {
                LoginView(
                    viewModel: LoginViewModel(
                        authService: authService,
                        sessionController: sessionController
                    )
                )
            } else {
                AccountListView(
                    viewModel: AccountListViewModel(
                        apiClient: apiClient,
                        sessionController: sessionController
                    )
                )
            }
        }
        .animation(.easeInOut, value: sessionController.session != nil)
    }
}

#Preview {
    let sessionController = AppSessionController(sessionStore: InMemorySessionStore())
    return ContentView(apiClient: MockApiClient(), authService: PreviewAuthService())
        .environmentObject(sessionController)
}

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
