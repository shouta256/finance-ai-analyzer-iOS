import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private let dashboardService: any DashboardService
    private let sessionController: AppSessionController

    init(
        dashboardService: any DashboardService,
        sessionController: AppSessionController
    ) {
        self.dashboardService = dashboardService
        self.sessionController = sessionController
    }

    func loadDashboard() async {
        guard !isLoading else { return }

        guard let session = sessionController.session, !session.isExpired else {
            snapshot = nil
            errorMessage = ApiError.unauthorized.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            snapshot = try await dashboardService.fetchDashboard(for: session)
        } catch let error as ApiError {
            errorMessage = error.localizedDescription
            snapshot = nil
        } catch {
            errorMessage = ApiError.unknown.localizedDescription
            snapshot = nil
        }
    }

    func signOut() {
        sessionController.clearSession()
    }

    var userDisplayName: String? {
        sessionController.session?.userDisplayName
    }
}
