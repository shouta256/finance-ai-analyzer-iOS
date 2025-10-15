import Foundation

@MainActor
final class AccountListViewModel: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    var totalBalance: Decimal {
        accounts.reduce(Decimal.zero) { partialResult, account in
            partialResult + account.balance
        }
    }

    var displayCurrencyCode: String {
        accounts.first?.currency ?? Locale.current.currency?.identifier ?? "USD"
    }

    private let apiClient: ApiClient
    private let sessionController: AppSessionController

    init(apiClient: ApiClient, sessionController: AppSessionController) {
        self.apiClient = apiClient
        self.sessionController = sessionController
    }

    func loadAccounts() async {
        guard !isLoading else { return }

        if let session = sessionController.session, session.isExpired {
            // トークンが期限切れの場合、リフレッシュを試みる
            if let refreshToken = session.refreshToken {
                do {
                    let newSession = try await apiClient.refreshAccessToken(refreshToken)
                    sessionController.apply(session: newSession)
                } catch {
                    sessionController.clearSession()
                    errorMessage = ApiError.unauthorized.localizedDescription
                    accounts = []
                    return
                }
            } else {
                sessionController.clearSession()
                errorMessage = ApiError.unauthorized.localizedDescription
                accounts = []
                return
            }
        }

        guard let accessToken = sessionController.session?.accessToken else {
            errorMessage = ApiError.unauthorized.localizedDescription
            accounts = []
            return
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            accounts = try await apiClient.fetchAccounts(accessToken: accessToken)
        } catch ApiError.unauthorized {
            // 401の場合、リフレッシュトークンで再試行
            if let refreshToken = sessionController.session?.refreshToken {
                do {
                    let newSession = try await apiClient.refreshAccessToken(refreshToken)
                    sessionController.apply(session: newSession)
                    // 新しいトークンで再度取得
                    accounts = try await apiClient.fetchAccounts(accessToken: newSession.accessToken)
                } catch {
                    sessionController.clearSession()
                    errorMessage = ApiError.unauthorized.localizedDescription
                }
            } else {
                sessionController.clearSession()
                errorMessage = ApiError.unauthorized.localizedDescription
            }
        } catch let error as ApiError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = ApiError.unknown.localizedDescription
        }
    }
}
