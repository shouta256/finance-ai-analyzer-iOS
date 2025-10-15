import Foundation

@MainActor
final class AppSessionController: ObservableObject {
    @Published private(set) var session: AuthSession?

    private let sessionStore: SessionStore

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
        loadPersistedSession()
    }

    func apply(session: AuthSession) {
        guard !session.isExpired else {
            clearSession()
            return
        }

        self.session = session
        sessionStore.session = session
    }

    func clearSession() {
        session = nil
        sessionStore.session = nil
    }

    private func loadPersistedSession() {
        guard let storedSession = sessionStore.session else {
            return
        }

        if storedSession.isExpired {
            sessionStore.session = nil
            session = nil
        } else {
            session = storedSession
        }
    }
}
