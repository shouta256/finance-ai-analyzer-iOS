import SwiftUI

struct AccountListView: View {
    @StateObject private var viewModel: AccountListViewModel
    @EnvironmentObject private var sessionController: AppSessionController

    init(viewModel: AccountListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                balanceHero

                accountsSection

                if let errorMessage = viewModel.errorMessage {
                    errorCard(message: errorMessage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .overlay(alignment: .center) {
            if viewModel.isLoading {
                ProgressView("Refreshing")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .task {
            await viewModel.loadAccounts()
        }
        .refreshable {
            await viewModel.loadAccounts()
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let displayName = sessionController.session?.userDisplayName {
                    Text(displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    signOut()
                } label: {
                    Label("Sign Out", systemImage: "arrow.right.square")
                        .labelStyle(.iconOnly)
                        .imageScale(.medium)
                        .accessibilityLabel("Sign out")
                }
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

    private var balanceHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.teal.opacity(0.9),
                            Color.blue.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 20) {
                Text("Overall balance")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.7))

                Text(CurrencyFormatter.string(from: viewModel.totalBalance, currencyCode: viewModel.displayCurrencyCode))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "creditcard.fill")
                            .font(.caption.weight(.semibold))
                        Text(accountsCountLabel)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18), in: Capsule(style: .continuous))

                    Spacer()

                    Text(viewModel.displayCurrencyCode)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.18), in: Capsule(style: .continuous))
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accountsCountLabel: String {
        let count = viewModel.accounts.count
        let noun = count == 1 ? "account" : "accounts"
        return "\(count) \(noun)"
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Linked Accounts")
                .font(.headline)

            if viewModel.accounts.isEmpty && !viewModel.isLoading {
                Text("No linked accounts yet. Connect a bank account to see balances here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.accounts) { account in
                        AccountCard(account: account)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("We couldn’t refresh accounts.", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .tint(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                Task { await viewModel.loadAccounts() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
    }

    private func signOut() {
        sessionController.clearSession()
    }
}

private struct AccountCard: View {
    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                    Text(account.institution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let accountType {
                    Text(accountType)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.12), in: Capsule(style: .continuous))
                }
            }

            Text(balanceString)
                .font(.title3.bold())
                .foregroundStyle(balanceColor)
                .monospacedDigit()

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(secondaryInfo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(account.currency)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.12), in: Capsule(style: .continuous))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.04))
        )
    }

    private var balanceString: String {
        CurrencyFormatter.string(from: account.balance, currencyCode: account.currency)
    }

    private var balanceColor: Color {
        account.balance < 0 ? .red : .primary
    }

    private var accountType: String? {
        guard let type = account.type?.trimmingCharacters(in: .whitespacesAndNewlines), !type.isEmpty else {
            return nil
        }
        return type
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private var secondaryInfo: String {
        let referenceDate = Date()
        if let lastTransactionAt = account.lastTransactionAt {
            let relative = AccountCard.relativeFormatter.localizedString(for: lastTransactionAt, relativeTo: referenceDate)
            return "Last activity \(relative)"
        } else if let linkedAt = account.linkedAt {
            let relative = AccountCard.relativeFormatter.localizedString(for: linkedAt, relativeTo: referenceDate)
            return "Linked \(relative)"
        } else {
            let relative = AccountCard.relativeFormatter.localizedString(for: account.createdAt, relativeTo: referenceDate)
            return "Created \(relative)"
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

#if DEBUG
#Preview {
    let sessionController = AppSessionController(sessionStore: InMemorySessionStore())
    sessionController.apply(
        session: AuthSession(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            idToken: nil,
            expiresAt: Date().addingTimeInterval(3600),
            userId: "mock-user-id",
            tokenType: "Bearer"
        )
    )

    return NavigationStack {
        AccountListView(
            viewModel: AccountListViewModel(
                apiClient: MockApiClient(),
                sessionController: sessionController
            )
        )
    }
    .environmentObject(sessionController)
}
#endif
