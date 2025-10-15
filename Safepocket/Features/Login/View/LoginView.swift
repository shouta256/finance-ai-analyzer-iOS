import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel

    init(viewModel: LoginViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text("Safepocket にサインイン")
                    .font(.title2.bold())

                Text("口座情報を閲覧するには Safepocket アカウントでの認証が必要です。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: signIn) {
                if viewModel.isAuthenticating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Safepocketでログイン")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isAuthenticating)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Safepocket")
    }

    private func signIn() {
        Task {
            await viewModel.signIn()
        }
    }
}

#Preview {
    NavigationStack {
        LoginView(
            viewModel: LoginViewModel(
                authService: PreviewAuthService(),
                sessionController: AppSessionController(sessionStore: InMemorySessionStore())
            )
        )
    }
}

@MainActor
private final class PreviewAuthService: AuthService {
    func signIn() async throws -> AuthSession {
        AuthSession(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            idToken: nil,
            expiresAt: Date().addingTimeInterval(600),
            userId: "preview-user-id",
            tokenType: "Bearer"
        )
    }
}
