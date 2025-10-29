import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedMonth: Date

    private let dashboardService: any DashboardService
    private let sessionController: AppSessionController
    private var lastLoadedMonth: Date?
    private var lastLoadTimestamp: Date?
    private let throttleInterval: TimeInterval = 30

    private static let calendar = Calendar(identifier: .gregorian)
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()

    init(
        dashboardService: any DashboardService,
        sessionController: AppSessionController
    ) {
        self.dashboardService = dashboardService
        self.sessionController = sessionController
        self.selectedMonth = Self.monthStart(from: Date())
    }

    func loadDashboard(month: Date? = nil, force: Bool = false) async {
        guard !isLoading || force else { return }

        if let month {
            selectedMonth = Self.monthStart(from: month)
        } else {
            selectedMonth = Self.monthStart(from: selectedMonth)
        }

        if !force,
           let lastMonth = lastLoadedMonth,
           DashboardViewModel.monthStart(from: lastMonth) == selectedMonth,
           let lastTimestamp = lastLoadTimestamp,
           Date().timeIntervalSince(lastTimestamp) < throttleInterval,
           snapshot != nil {
            return
        }

        guard let session = sessionController.session, !session.isExpired else {
            snapshot = nil
            errorMessage = ApiError.unauthorized.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            snapshot = try await dashboardService.fetchDashboard(for: session, month: selectedMonth)
            lastLoadedMonth = selectedMonth
            lastLoadTimestamp = Date()
        } catch let error as ApiError {
            errorMessage = error.localizedDescription
            snapshot = nil
        } catch {
            errorMessage = ApiError.unknown.localizedDescription
            snapshot = nil
        }
    }

    func moveMonth(offset: Int) async {
        guard offset != 0 else { return }
        guard let newMonth = Self.calendar.date(byAdding: .month, value: offset, to: selectedMonth) else { return }
        if offset > 0, !canMoveForward { return }
        await loadDashboard(month: newMonth, force: true)
    }

    func signOut() {
        sessionController.clearSession()
    }

    var userDisplayName: String? {
        sessionController.session?.userDisplayName
    }

    var monthTitle: String {
        Self.monthFormatter.string(from: selectedMonth)
    }

    var canMoveForward: Bool {
        guard let next = Self.calendar.date(byAdding: .month, value: 1, to: selectedMonth) else {
            return false
        }
        return next <= Self.monthStart(from: Date())
    }

    var availableMonths: [Date] {
        let start = Self.monthStart(from: Date())
        return (0..<12).compactMap { offset in
            Self.calendar.date(byAdding: .month, value: -offset, to: start)
        }
    }

    static func monthStart(from date: Date) -> Date {
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return date
        }
        return start
    }
}
