import Foundation
import Testing
@testable import Safepocket

struct SafepocketTests {

    @MainActor
    @Test("Account list loads mock accounts")
    func accountListLoadsMockAccounts() async throws {
        let sessionController = AppSessionController(sessionStore: InMemorySessionStore())
        sessionController.apply(
            session: AuthSession(
                accessToken: "mock-access-token",
                refreshToken: "mock-refresh-token",
                idToken: nil,
                expiresAt: Date().addingTimeInterval(3600),
                userId: "test-user-id",
                tokenType: "Bearer"
            )
        )

        let viewModel = AccountListViewModel(apiClient: MockApiClient(), sessionController: sessionController)
        await viewModel.loadAccounts()

        #expect(viewModel.accounts == Account.previewAccounts)
    }
}
