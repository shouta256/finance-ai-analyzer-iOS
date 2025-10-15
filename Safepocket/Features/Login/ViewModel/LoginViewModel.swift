import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published private(set) var isAuthenticating: Bool = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let sessionController: AppSessionController

    init(authService: AuthService, sessionController: AppSessionController) {
        self.authService = authService
        self.sessionController = sessionController
    }

    func signIn() async {
        errorMessage = nil
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let session = try await authService.signIn()
            sessionController.apply(session: session)
        } catch let error as ApiError {
            errorMessage = error.localizedDescription
        } catch let error as AuthServiceError {
            if case .cancelled = error {
                return
            }
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = ApiError.unknown.localizedDescription
        }
    }
}
