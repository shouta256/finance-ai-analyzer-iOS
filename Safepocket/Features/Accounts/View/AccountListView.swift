import SwiftUI

struct AccountListView: View {
    @StateObject private var viewModel: AccountListViewModel
    @EnvironmentObject private var sessionController: AppSessionController

    init(viewModel: AccountListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.string(from: viewModel.totalBalance, currencyCode: viewModel.displayCurrencyCode))
                        .font(.title2.bold())
                }
                .padding(.vertical, 4)
            }

            Section("Accounts") {
                if viewModel.accounts.isEmpty && !viewModel.isLoading {
                    Text("No linked accounts yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.accounts) { account in
                        AccountRow(account: account)
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .center) {
            if viewModel.isLoading {
                ProgressView("Refreshing")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out", action: signOut)
            }
            ToolbarItem(placement: .topBarLeading) {
                if let displayName = sessionController.session?.userDisplayName {
                    Text(displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func signOut() {
        sessionController.clearSession()
    }
}

private struct AccountRow: View {
    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(account.name)
                .font(.headline)
            Text(account.bankName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.string(from: account.balance, currencyCode: account.currency))
                .font(.body.monospacedDigit())
                .foregroundStyle(account.balance < 0 ? Color.red : Color.primary)
                .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }
}

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
