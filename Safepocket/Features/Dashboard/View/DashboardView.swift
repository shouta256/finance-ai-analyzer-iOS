import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var summaryViewModel: AISummaryViewModel
    @State private var pendingAction: DashboardAction?
    @State private var isShowingSettings: Bool = false

    init(
        viewModel: DashboardViewModel,
        summaryViewModel: AISummaryViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _summaryViewModel = StateObject(wrappedValue: summaryViewModel)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                heroSection

                if let snapshot = viewModel.snapshot {
                    insightsSection(snapshot: snapshot)

                    aiSummarySection

                    if !snapshot.anomalyAlerts.isEmpty {
                        anomalySection(alerts: snapshot.anomalyAlerts)
                    }

                    if !snapshot.recentTransactions.isEmpty {
                        transactionsSection(transactions: snapshot.recentTransactions)
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    errorState(message: errorMessage)
                } else if !viewModel.isLoading {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .overlay(alignment: .center) {
            if viewModel.isLoading {
                ProgressView("Loading dashboard…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let displayName = viewModel.userDisplayName {
                    Text(displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .labelStyle(.iconOnly)
                        .imageScale(.medium)
                        .accessibilityLabel("Dashboard settings")
                }
            }
        }
        .task {
            summaryViewModel.selectedMonth = viewModel.selectedMonth
            async let dashboard: Void = viewModel.loadDashboard()
            async let summary: Void = summaryViewModel.loadSummary()
            _ = await (dashboard, summary)
        }
        .refreshable {
            await performFullRefresh(force: true)
        }
        .alert(item: $pendingAction) { action in
            Alert(
                title: Text(action.alertTitle),
                message: Text(action.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                DashboardSettingsView(
                    onAction: { pendingAction = $0 },
                    onRefresh: { refreshDashboardData() },
                    onSignOut: {
                        viewModel.signOut()
                        isShowingSettings = false
                    }
                )
            }
        }
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.indigo.opacity(0.9),
                            Color.blue.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 20) {
                monthSelector

                VStack(alignment: .leading, spacing: 12) {
                    Text("Net position")
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.7))

                    Text(currentNetValue)
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)

                    if let summary = viewModel.snapshot?.summary {
                        HStack(spacing: 16) {
                            HeroMetricPill(
                                title: "Income",
                                value: CurrencyFormatter.string(from: summary.income, currencyCode: summary.currencyCode),
                                icon: "arrow.down.circle.fill",
                                tint: Color.white.opacity(0.18)
                            )
                            HeroMetricPill(
                                title: "Expenses",
                                value: CurrencyFormatter.string(from: summary.expenses, currencyCode: summary.currencyCode),
                                icon: "arrow.up.circle.fill",
                                tint: Color.white.opacity(0.12)
                            )
                        }
                    } else {
                        Text("Link an account to unlock your month-by-month insights.")
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
    }

    private var monthSelector: some View {
        HStack(spacing: 12) {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.white)
                    .background(Color.white.opacity(0.16), in: Circle())
            }
            .accessibilityLabel("Previous month")

            Menu {
                ForEach(viewModel.availableMonths, id: \.self) { month in
                    Button {
                        selectMonth(month)
                    } label: {
                        let isSelected = DashboardViewModel.monthStart(from: month) == viewModel.selectedMonth
                        Label(
                            Self.menuFormatter.string(from: month),
                            systemImage: isSelected ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.monthTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.white)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.18), in: Capsule(style: .continuous))
            }
            .menuOrder(.fixed)

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(viewModel.canMoveForward ? Color.white : Color.white.opacity(0.3))
                    .background(Color.white.opacity(viewModel.canMoveForward ? 0.16 : 0.08), in: Circle())
            }
            .accessibilityLabel("Next month")
            .disabled(!viewModel.canMoveForward)
        }
    }

    private var currentNetValue: String {
        guard let summary = viewModel.snapshot?.summary else {
            return "—"
        }
        return CurrencyFormatter.string(from: summary.net, currencyCode: summary.currencyCode)
    }

    private func shiftMonth(by offset: Int) {
        guard offset != 0 else { return }
        Task {
            await viewModel.moveMonth(offset: offset)
            let updated = viewModel.selectedMonth
            await MainActor.run {
                summaryViewModel.selectedMonth = updated
            }
            await summaryViewModel.loadSummary(force: true)
        }
    }

    private func selectMonth(_ month: Date) {
        Task {
            await viewModel.loadDashboard(month: month, force: true)
            let normalized = DashboardViewModel.monthStart(from: month)
            await MainActor.run {
                summaryViewModel.selectedMonth = normalized
            }
            await summaryViewModel.loadSummary(force: true)
        }
    }

    private func refreshDashboardData() {
        Task {
            await performFullRefresh(force: true)
        }
    }

    private func performFullRefresh(force: Bool) async {
        await viewModel.loadDashboard(force: force)
        summaryViewModel.selectedMonth = viewModel.selectedMonth
        await summaryViewModel.loadSummary(force: force)
    }

    private func errorState(message: String) -> some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("We couldn’t load the dashboard.", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .tint(.orange)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task {
                        await viewModel.loadDashboard(force: true)
                        summaryViewModel.selectedMonth = viewModel.selectedMonth
                        await summaryViewModel.loadSummary(force: true)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private var emptyState: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("No dashboard data yet")
                    .font(.headline)
                Text("Link your accounts to start seeing spending insights, anomalies, and your latest transactions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static let menuFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()

    private func insightsSection(snapshot: DashboardSnapshot) -> some View {
        AdaptiveGrid(minimumWidth: 280) {
            DashboardCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spending by Category")
                            .font(.headline)
                        Text("Where your money went this month.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if snapshot.categories.isEmpty {
                        Text("No category insights yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(snapshot.categories) { category in
                                CategorySpendRow(category: category, currencyCode: snapshot.summary.currencyCode)
                            }
                        }
                    }
                }
            }

            DashboardCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Merchants")
                            .font(.headline)
                        Text("Highest activity merchants this month.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if snapshot.merchants.isEmpty {
                        Text("No merchant activity yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(snapshot.merchants) { merchant in
                                MerchantRow(merchant: merchant, currencyCode: snapshot.summary.currencyCode)
                            }
                        }
                    }
                }
            }
        }
    }

    private var aiSummarySection: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Label("AI Highlights", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                    Button {
                        Task {
                            summaryViewModel.selectedMonth = viewModel.selectedMonth
                            await summaryViewModel.loadSummary(force: true)
                        }
                    } label: {
                        Label("Generate", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.small)
                    .disabled(summaryViewModel.isLoading)
                }

                if let summary = summaryViewModel.summary {
                    Text("Updated \(Self.detectedFormatter.string(from: summary.generatedAt))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text("Question: \(summaryViewModel.prompt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Group {
                    if summaryViewModel.isLoading {
                        ProgressView("Generating summary…")
                    } else if let summary = summaryViewModel.summary {
                        VStack(alignment: .leading, spacing: 14) {
                            summaryText(from: summary.response)
                                .font(.body)

                            Button {
                                copyToPasteboard(summary.response)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemBackground))
                        )
                    } else if let errorMessage = summaryViewModel.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                            Button {
                                Task {
                                    await summaryViewModel.loadSummary(force: true)
                                }
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    } else {
                        Text("AI summary will appear here once generated.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func anomalySection(alerts: [DashboardSnapshot.AnomalyAlert]) -> some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Anomaly Alerts")
                        .font(.headline)
                    Text("Highlighting spend spikes versus your usual pattern.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                AnomalyAlertsView(
                    alerts: alerts,
                    percentageFormatter: formattedPercentage(_:))
            }
        }
    }

    private func transactionsSection(transactions: [DashboardSnapshot.RecentTransaction]) -> some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Transactions")
                        .font(.headline)
                    Text("Last synced transactions ordered by activity.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                }
            }
        }
    }

    private func formattedPercentage(_ value: Double) -> String {
        let percent = value * 100
        return String(format: "%.1f%%", percent)
    }

    @ViewBuilder
    private func summaryText(from markdown: String) -> some View {
        if let attributed = try? AttributedString(markdown: markdown) {
            Text(attributed)
                .font(.body)
        } else {
            Text(markdown)
                .font(.body)
        }
    }

    private func copyToPasteboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

private extension DashboardView {
    enum DashboardAction: String, Identifiable {
        case linkAccounts
        case demoData
        case syncTransactions

        var id: String { rawValue }

        var alertTitle: String {
            switch self {
            case .linkAccounts:
                return "Link Accounts"
            case .demoData:
                return "Demo Data"
            case .syncTransactions:
                return "Sync Transactions"
            }
        }

        var alertMessage: String {
            switch self {
            case .linkAccounts:
                return "Plaid linking will be available in an upcoming build."
            case .demoData:
                return "Demo datasets load automatically in this preview."
            case .syncTransactions:
                return "Transaction sync is triggered nightly. Manual sync will arrive soon."
            }
        }
    }

    static let detectedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy, h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Components


private struct AdaptiveGrid<Content: View>: View {
    let minimumWidth: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: minimumWidth), spacing: 16)
            ],
            alignment: .leading,
            spacing: 16,
            content: { content }
        )
    }
}

private struct HeroMetricPill: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.white.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                Text(value)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tint, in: Capsule(style: .continuous))
    }
}

private struct DashboardCard<Content: View>: View {
    let background: Color
    @ViewBuilder let content: Content

    init(background: Color = Color(.secondarySystemGroupedBackground), @ViewBuilder content: () -> Content) {
        self.background = background
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16, content: { content })
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.04))
            )
    }
}

private struct DashboardSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let onAction: (DashboardView.DashboardAction) -> Void
    let onRefresh: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        List {
            Section("Accounts & Sync") {
                Button {
                    onAction(.linkAccounts)
                    dismiss()
                } label: {
                    Label("Link Accounts", systemImage: "link.badge.plus")
                }

                Button {
                    onAction(.syncTransactions)
                    dismiss()
                } label: {
                    Label("Sync Transactions", systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    onAction(.demoData)
                    dismiss()
                } label: {
                    Label("Load Demo Data", systemImage: "sparkles")
                }

                Button {
                    onRefresh()
                    dismiss()
                } label: {
                    Label("Refresh Dashboard Data", systemImage: "arrow.clockwise")
                }
            }

            Section {
                Button(role: .destructive) {
                    onSignOut()
                    dismiss()
                } label: {
                    Label("Sign Out", systemImage: "arrow.right.square")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Dashboard Settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct CategorySpendRow: View {
    let category: DashboardSnapshot.CategorySpend
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(CurrencyFormatter.string(from: category.amount, currencyCode: currencyCode))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(category.amount < 0 ? Color.red : Color.primary)
            }
            ProgressView(value: min(max(category.percentage, 0), 1))
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
            Text(String(format: "%.1f%% of spend", category.percentage * 100))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MerchantRow: View {
    let merchant: DashboardSnapshot.MerchantActivity
    let currencyCode: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(merchant.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(merchant.transactionCount) \(merchant.transactionCount == 1 ? "transaction" : "transactions")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(CurrencyFormatter.string(from: merchant.amount, currencyCode: currencyCode))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(merchant.amount < 0 ? Color.red : Color.primary)
        }
    }
}

private struct TransactionRow: View {
    let transaction: DashboardSnapshot.RecentTransaction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(transaction.merchant)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(transaction.status.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(transaction.status == .posted ? Color.green : Color.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.dateFormatter.string(from: transaction.postedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(transaction.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(CurrencyFormatter.string(from: transaction.amount, currencyCode: transaction.currencyCode))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(transaction.amount < 0 ? Color.red : Color.primary)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy, h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

private struct AnomalyAlertsView: View {
    let alerts: [DashboardSnapshot.AnomalyAlert]
    let percentageFormatter: (Double) -> String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .compact {
            alertsStack
        } else {
            alertsGrid
        }
    }

    private var alertsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                header("Merchant").gridColumnAlignment(.leading)
                header("Amount").gridColumnAlignment(.trailing)
                header("Diff vs Typical").gridColumnAlignment(.trailing)
                header("Budget Impact").gridColumnAlignment(.trailing)
                header("Detected").gridColumnAlignment(.trailing)
            }

            Divider()
                .gridCellColumns(5)

            ForEach(Array(alerts.enumerated()), id: \.element.id) { index, alert in
                GridRow {
                    Text(alert.merchant)
                        .font(.subheadline.weight(.semibold))
                        .gridColumnAlignment(.leading)

                    amountText(for: alert)
                        .gridColumnAlignment(.trailing)

                    Text(CurrencyFormatter.string(from: alert.differenceFromTypical, currencyCode: alert.currencyCode))
                        .font(.subheadline.monospacedDigit())
                        .gridColumnAlignment(.trailing)

                    Text(percentageFormatter(alert.budgetImpactPercentage))
                        .font(.subheadline)
                        .gridColumnAlignment(.trailing)

                    Text(DashboardView.detectedFormatter.string(from: alert.detectedAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                }
                .padding(.vertical, 4)

                if index < alerts.count - 1 {
                    Divider()
                        .gridCellColumns(5)
                }
            }
        }
    }

    private var alertsStack: some View {
        VStack(spacing: 12) {
            ForEach(alerts) { alert in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text(alert.merchant)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        amountText(for: alert)
                    }

                    HStack {
                        Text("Diff vs Typical")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(CurrencyFormatter.string(from: alert.differenceFromTypical, currencyCode: alert.currencyCode))
                            .font(.subheadline.monospacedDigit())
                    }

                    HStack {
                        Text("Budget Impact")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(percentageFormatter(alert.budgetImpactPercentage))
                            .font(.subheadline)
                    }

                    Text(DashboardView.detectedFormatter.string(from: alert.detectedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func amountText(for alert: DashboardSnapshot.AnomalyAlert) -> some View {
        Text(CurrencyFormatter.string(from: alert.amount, currencyCode: alert.currencyCode))
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(alert.amount < 0 ? Color.red : Color.primary)
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    DashboardViewPreview()
}

private struct DashboardViewPreview: View {
    private let sessionController: AppSessionController

    init() {
        let controller = AppSessionController(sessionStore: InMemorySessionStore())
        controller.apply(
            session: AuthSession(
                accessToken: "preview-access",
                refreshToken: "preview-refresh",
                idToken: nil,
                expiresAt: Date().addingTimeInterval(3600),
                userId: "preview-user",
                tokenType: "Bearer"
            )
        )
        self.sessionController = controller
    }

    var body: some View {
        NavigationStack {
            DashboardView(
                viewModel: DashboardViewModel(
                    dashboardService: DemoDashboardService(),
                    sessionController: sessionController
                ),
                summaryViewModel: AISummaryViewModel(
                    prompt: "Where am I spending the most?",
                    aiService: DemoAIService(),
                    sessionController: sessionController
                )
            )
        }
        .environmentObject(sessionController)
    }
}
