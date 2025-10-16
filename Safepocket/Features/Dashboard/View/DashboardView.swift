import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var summaryViewModel: AISummaryViewModel
    @State private var pendingAction: DashboardAction?

    init(
        viewModel: DashboardViewModel,
        summaryViewModel: AISummaryViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _summaryViewModel = StateObject(wrappedValue: summaryViewModel)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                header

                actionButtons

                if let snapshot = viewModel.snapshot {
                    summarySection(from: snapshot.summary)

                    overviewSection(snapshot: snapshot)

                    if let highlight = snapshot.monthlyHighlight {
                        highlightSection(highlight)
                    }

                    if !snapshot.anomalyAlerts.isEmpty {
                        anomalySection(alerts: snapshot.anomalyAlerts)
                    }

                    if !snapshot.recentTransactions.isEmpty {
                        transactionsSection(transactions: snapshot.recentTransactions)
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    DashboardCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("We couldn’t load the dashboard.", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .tint(.orange)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Retry") {
                                Task { await viewModel.loadDashboard() }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                } else if !viewModel.isLoading {
                    DashboardCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No dashboard data yet")
                                .font(.headline)
                            Text("Link your accounts to start seeing spending insights, anomalies, and your latest transactions.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay(alignment: .center) {
            if viewModel.isLoading {
                ProgressView("Loading dashboard…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                Button("Sign Out") {
                    viewModel.signOut()
                }
            }
        }
        .task {
            async let dashboard: Void = viewModel.loadDashboard()
            async let summary: Void = summaryViewModel.loadSummary()
            await dashboard
            await summary
        }
        .refreshable {
            await viewModel.loadDashboard()
            await summaryViewModel.loadSummary(force: true)
        }
        .alert(item: $pendingAction) { action in
            Alert(
                title: Text(action.alertTitle),
                message: Text(action.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Safepocket Dashboard")
                .font(.largeTitle.bold())
            Text("Secure financial intelligence with Plaid sandbox connectivity.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                DashboardActionButton(title: "Link Accounts with Plaid", style: .primary) {
                    pendingAction = .linkAccounts
                }
                DashboardActionButton(title: "Try Demo Data", style: .tinted(.green)) {
                    pendingAction = .demoData
                }
                DashboardActionButton(title: "Sync Transactions", style: .plain) {
                    pendingAction = .syncTransactions
                }
                DashboardActionButton(title: "Generate AI Summary", style: .plain) {
                    Task {
                        await summaryViewModel.loadSummary(force: true)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func summarySection(from summary: DashboardSnapshot.Summary) -> some View {
        AdaptiveGrid(minimumWidth: 180) {
            SummaryCard(
                title: "Income",
                value: CurrencyFormatter.string(from: summary.income, currencyCode: summary.currencyCode),
                caption: "Current month",
                color: Color.green.opacity(0.12),
                valueColor: .green
            )

            SummaryCard(
                title: "Expenses",
                value: CurrencyFormatter.string(from: summary.expenses, currencyCode: summary.currencyCode),
                caption: "Current month",
                color: Color.red.opacity(0.12),
                valueColor: .red
            )

            SummaryCard(
                title: "Net",
                value: CurrencyFormatter.string(from: summary.net, currencyCode: summary.currencyCode),
                caption: "Income - Expenses",
                color: Color.blue.opacity(0.12),
                valueColor: summary.net >= 0 ? .green : .red
            )
        }
    }

    private func overviewSection(snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            AdaptiveGrid(minimumWidth: 260) {
                DashboardCard {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Spend by Category")
                                .font(.headline)
                            Text("Top categories for the month.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if snapshot.categories.isEmpty {
                            Text("No spending yet.")
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
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Top Merchants")
                                .font(.headline)
                            Text("Highest activity merchants.")
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

            aiSummarySection
        }
    }

    private func highlightSection(_ highlight: DashboardSnapshot.MonthlyHighlight) -> some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(highlight.title)
                    .font(.headline)
                Text(highlight.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Reporting period \(highlight.generatedForPeriod)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var aiSummarySection: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Summary")
                            .font(.headline)
                        Text("SafepocketのAIが支出データから要約を生成します。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(summaryViewModel.prompt) {
                        Task {
                            await summaryViewModel.loadSummary(force: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.small)
                }

                Group {
                    if summaryViewModel.isLoading {
                        ProgressView("Generating summary…")
                    } else if let summary = summaryViewModel.summary {
                        VStack(alignment: .leading, spacing: 12) {
                            summaryText(from: summary.response)

                            HStack(spacing: 12) {
                                Button("Copy") {
                                    copyToPasteboard(summary.response)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Text("Updated \(Self.detectedFormatter.string(from: summary.generatedAt))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } else if let errorMessage = summaryViewModel.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                            Button("Retry") {
                                Task { await summaryViewModel.loadSummary(force: true) }
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

private struct DashboardActionButton: View {
    enum Style {
        case primary
        case plain
        case tinted(Color)
    }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        switch style {
        case .primary:
            Button(action: action) {
                label.foregroundStyle(Color.white)
            }
            .buttonStyle(DashboardPrimaryButtonStyle())
        case .plain:
            Button(action: action) {
                label.foregroundStyle(Color.accentColor)
            }
            .buttonStyle(DashboardOutlineButtonStyle())
        case .tinted(let color):
            Button(action: action) {
                label.foregroundStyle(color)
            }
            .buttonStyle(DashboardTintedButtonStyle(color: color))
        }
    }

    private var label: some View {
        Text(title)
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: 140)
    }
}

private struct DashboardPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(configuration.isPressed ? Color.indigo.opacity(0.8) : Color.indigo)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct DashboardOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .stroke(Color.accentColor.opacity(configuration.isPressed ? 0.6 : 1.0), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct DashboardTintedButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(color.opacity(configuration.isPressed ? 0.18 : 0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

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

private struct SummaryCard: View {
    let title: String
    let value: String
    let caption: String
    let color: Color
    let valueColor: Color

    var body: some View {
        DashboardCard(background: color) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }
}

private struct DashboardCard<Content: View>: View {
    let background: Color
    @ViewBuilder let content: Content

    init(background: Color = Color(.systemBackground), @ViewBuilder content: () -> Content) {
        self.background = background
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12, content: { content })
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
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
                    prompt: "何に一番お金使ってる？",
                    aiService: DemoAIService(),
                    sessionController: sessionController
                )
            )
        }
        .environmentObject(sessionController)
    }
}
