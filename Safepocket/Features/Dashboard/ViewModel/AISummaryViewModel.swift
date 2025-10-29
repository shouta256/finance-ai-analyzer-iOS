import Foundation

@MainActor
final class AISummaryViewModel: ObservableObject {
    @Published private(set) var summary: AISummary?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedMonth: Date

    let prompt: String

    private let aiService: any AIService
    private let sessionController: AppSessionController

    init(
        prompt: String,
        aiService: any AIService,
        sessionController: AppSessionController,
        selectedMonth: Date = Date()
    ) {
        self.prompt = prompt
        self.aiService = aiService
        self.sessionController = sessionController
        self.selectedMonth = Self.monthStart(from: selectedMonth)
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
            let shouldRegenerate = force || summary == nil
            summary = try await aiService.generateSummary(
                for: prompt,
                month: selectedMonth,
                regenerate: shouldRegenerate,
                session: session
            )
        } catch let error as ApiError {
            errorMessage = error.localizedDescription
            summary = nil
        } catch {
            errorMessage = ApiError.unknown.localizedDescription
            summary = nil
        }
    }

    private static func monthStart(from date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return date
        }
        return start
    }
}
