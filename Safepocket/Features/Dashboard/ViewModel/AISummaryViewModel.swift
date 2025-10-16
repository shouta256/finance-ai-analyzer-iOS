import Foundation

@MainActor
final class AISummaryViewModel: ObservableObject {
    @Published private(set) var summary: AISummary?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    let prompt: String

    private let aiService: any AIService
    private let sessionController: AppSessionController

    init(
        prompt: String,
        aiService: any AIService,
        sessionController: AppSessionController
    ) {
        self.prompt = prompt
        self.aiService = aiService
        self.sessionController = sessionController
    }

    func loadSummary(force: Bool = false) async {
        guard !isLoading else { return }

        if !force, summary != nil {
            return
        }

        guard let session = sessionController.session, !session.isExpired else {
            summary = nil
            errorMessage = ApiError.unauthorized.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            summary = try await aiService.generateSummary(for: prompt, session: session)
        } catch let error as ApiError {
            errorMessage = error.localizedDescription
            summary = nil
        } catch {
            errorMessage = ApiError.unknown.localizedDescription
            summary = nil
        }
    }
}
