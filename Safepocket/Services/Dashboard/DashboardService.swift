import Foundation

protocol DashboardService {
    func fetchDashboard(for session: AuthSession) async throws -> DashboardSnapshot
}

struct DemoDashboardService: DashboardService {
    func fetchDashboard(for session: AuthSession) async throws -> DashboardSnapshot {
        // Simulate a short network delay so the UI can surface loading feedback.
        try await Task.sleep(nanoseconds: 150_000_000)
        return .sample
    }
}
