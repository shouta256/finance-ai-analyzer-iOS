import SwiftUI
import Charts
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

    private func spendingHealthScore(for summary: DashboardSnapshot.Summary) -> Int {
        let income = NSDecimalNumber(decimal: summary.income).doubleValue
        let expenses = abs(NSDecimalNumber(decimal: summary.expenses).doubleValue)

        if income <= 0 {
            if expenses == 0 {
                return 100
            }
            return max(10, 60 - Int(min(expenses / 100, 40)))
        }

        let ratio = min(max(expenses / income, 0), 2)
        let rawScore = Int(round((1 - ratio) * 100))
        return max(0, min(100, rawScore))
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
        AdaptiveGrid(minimumWidth: 320) {
            DashboardCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net Trend")
                            .font(.headline)
                        Text("Monthly net movement based on the selected period.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    NetTrendCard(
                        points: snapshot.netTrend,
                        currencyCode: snapshot.summary.currencyCode
                    )
                }
            }

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
                        let score = spendingHealthScore(for: snapshot.summary)
                        CategorySpendingCard(
                            categories: snapshot.categories,
                            summary: snapshot.summary,
                            score: score,
                            scoreLabel: viewModel.monthTitle
                        )
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
                        MerchantActivityCard(
                            merchants: snapshot.merchants,
                            currencyCode: snapshot.summary.currencyCode
                        )
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

private struct CategorySpendingCard: View {
    let categories: [DashboardSnapshot.CategorySpend]
    let summary: DashboardSnapshot.Summary
    let score: Int
    let scoreLabel: String

    private struct Segment: Identifiable, Equatable {
        let id = UUID()
        let category: DashboardSnapshot.CategorySpend
        let start: Double
        let end: Double
        let color: Color
    }

    private var palette: [Color] {
        [
            Color(red: 56/255, green: 189/255, blue: 248/255), // sky-400
            Color(red: 99/255, green: 102/255, blue: 241/255), // indigo-500
            Color(red: 129/255, green: 140/255, blue: 248/255), // indigo-400
            Color(red: 167/255, green: 139/255, blue: 250/255), // violet-400
            Color(red: 192/255, green: 132/255, blue: 252/255), // purple-400
            Color(red: 232/255, green: 121/255, blue: 249/255), // fuchsia-400
            Color(red: 244/255, green: 114/255, blue: 182/255)  // pink-400
        ]
    }

    private var segments: [Segment] {
        let amounts = categories.map { max(abs(NSDecimalNumber(decimal: $0.amount).doubleValue), 0.0) }
        let total = amounts.reduce(0, +)
        guard total > 0 else { return [] }

        var start: Double = 0
        return categories.enumerated().map { index, category in
            let value = amounts[index] / total
            let end = start + value
            defer { start = end }
            return Segment(
                category: category,
                start: start,
                end: min(end, 1),
                color: palette[index % palette.count]
            )
        }
    }

    private var scoreColor: Color {
        switch score {
        case 70...:
            return Color(red: 22/255, green: 163/255, blue: 74/255)
        case 40..<70:
            return Color(red: 245/255, green: 158/255, blue: 11/255)
        default:
            return Color(red: 220/255, green: 38/255, blue: 38/255)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if segments.isEmpty {
                Text("Link more accounts to unlock category insights.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                GeometryReader { geometry in
                    let diameter = min(geometry.size.width, geometry.size.height)
                    let lineWidth = max(min(diameter * 0.16, 26), 14)
                    let segmentGap = 0.008

                    ZStack {
                        ForEach(segments) { segment in
                            let span = segment.end - segment.start
                            let adjustedStart = span > segmentGap
                                ? segment.start + segmentGap / 2
                                : segment.start
                            let adjustedEnd = span > segmentGap
                                ? segment.end - segmentGap / 2
                                : segment.end

                            if adjustedEnd > adjustedStart {
                                Circle()
                                    .trim(from: adjustedStart, to: adjustedEnd)
                                    .stroke(
                                        segment.color,
                                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                            }
                        }

                        VStack(spacing: 4) {
                            Text("\(score)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(scoreColor)
                                .contentTransition(.numericText())
                            Text(scoreLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: diameter, height: diameter)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Spending score \(score) out of 100 for \(scoreLabel)")
                }
                .frame(height: 200)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    CategoryLegendRow(
                        color: segment.color,
                        name: segment.category.name,
                        amount: segment.category.amount,
                        percentage: segment.category.percentage,
                        currencyCode: summary.currencyCode,
                        showDivider: index < segments.count - 1
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.32), value: segments)
    }
}

private struct NetTrendCard: View {
    let points: [DashboardSnapshot.NetTrendPoint]
    let currencyCode: String

    private var orderedPoints: [DashboardSnapshot.NetTrendPoint] {
        points.sorted { $0.date < $1.date }
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 37/255, green: 99/255, blue: 235/255),
                Color(red: 168/255, green: 85/255, blue: 247/255),
                Color(red: 236/255, green: 72/255, blue: 153/255)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var hasTrend: Bool {
        orderedPoints.count >= 2
    }

    var body: some View {
        if !hasTrend {
            Text("Not enough transaction history yet. Link accounts or expand the date range to see your trend.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Chart {
                let trendPoints = orderedPoints

                ForEach(trendPoints) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Net", point.netValue)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(gradient.opacity(0.18))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Net", point.netValue)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 5, lineCap: .round))
                    .foregroundStyle(gradient)
                }

                RuleMark(y: .value("Zero", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(Color.primary.opacity(0.12))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                    AxisValueLabel {
                        if let dateValue = value.as(Date.self) {
                            Text(Self.axisFormatter.string(from: dateValue))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Net trend over the selected period")
            .accessibilityValue(
                orderedPoints
                    .map { "\(Self.axisFormatter.string(from: $0.date)): \(CurrencyFormatter.string(from: $0.net, currencyCode: currencyCode))" }
                    .joined(separator: ", ")
            )
        }
    }

    private static let axisFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()
}

private struct MerchantActivityCard: View {
    let merchants: [DashboardSnapshot.MerchantActivity]
    let currencyCode: String

    struct MerchantEntry: Identifiable {
        let id = UUID()
        let name: String
        let amount: Double
        let rawAmount: Decimal
        let count: Int
        let color: Color
    }

    private var entries: [MerchantEntry] {
        let palette: [Color] = [
            Color(red: 37/255, green: 99/255, blue: 235/255),
            Color(red: 59/255, green: 130/255, blue: 246/255),
            Color(red: 99/255, green: 102/255, blue: 241/255),
            Color(red: 6/255, green: 182/255, blue: 212/255),
            Color(red: 14/255, green: 165/255, blue: 233/255)
        ]

        return merchants.enumerated().map { index, merchant in
            MerchantEntry(
                name: merchant.name,
                amount: max(abs(NSDecimalNumber(decimal: merchant.amount).doubleValue), 0),
                rawAmount: merchant.amount,
                count: merchant.transactionCount,
                color: palette[index % palette.count]
            )
        }
    }

    private var maxValue: Double {
        entries.map(\.amount).max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if entries.isEmpty {
                Text("No merchant activity yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Amount", entry.amount),
                        y: .value("Merchant", entry.name)
                    )
                    .annotation(position: .trailing, alignment: .trailing) {
                        Text(CurrencyFormatter.string(from: entry.rawAmount, currencyCode: currencyCode))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(entry.color)
                    .cornerRadius(8)
                }
                .chartLegend(.hidden)
                .chartXAxis(.hidden)
                .chartYScale(domain: entries.map(\.name))
                .chartXScale(domain: 0...(maxValue * 1.15 + 0.01))
                .frame(height: CGFloat(entries.count) * 32 + 36)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(entries) { entry in
                        MerchantLegendRow(entry: entry, currencyCode: currencyCode)
                    }
                }
            }
        }
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

private struct CategoryLegendRow: View {
    let color: Color
    let name: String
    let amount: Decimal
    let percentage: Double
    let currencyCode: String
    let showDivider: Bool

    private var displayName: String {
        let replaced = name.replacingOccurrences(of: "_", with: " ")
        return replaced
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCapitalized
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(String(format: "%.1f%% of spend", max(percentage, 0) * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(CurrencyFormatter.string(from: amount, currencyCode: currencyCode))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(amount < 0 ? Color.red : Color.primary)
            }

            if showDivider {
                Divider()
            }
        }
    }
}

private struct MerchantLegendRow: View {
    let entry: MerchantActivityCard.MerchantEntry
    let currencyCode: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(entry.color)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(entry.count) \(entry.count == 1 ? "transaction" : "transactions")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(CurrencyFormatter.string(from: entry.rawAmount, currencyCode: currencyCode))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(entry.rawAmount < 0 ? Color.red : Color.primary)
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
