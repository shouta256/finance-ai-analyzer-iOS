import SwiftUI

struct AIChatView: View {
    @StateObject private var viewModel: AIChatViewModel
    @FocusState private var isInputFocused: Bool

    init(viewModel: AIChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 20) {
            content

            inputBar
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color(.secondarySystemGroupedBackground),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("AI Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.retry() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.medium)
                }
                .accessibilityLabel("Retry loading messages")
                .disabled(viewModel.isLoadingHistory)
            }
        }
        .task {
            await viewModel.loadInitialMessages()
        }
    }


    private var content: some View {
        Group {
            if viewModel.isLoadingHistory && viewModel.messages.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting to the assistant…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let errorMessage = viewModel.errorMessage, viewModel.messages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await viewModel.retry() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ChatMessagesList(
                    messages: viewModel.messages,
                    editingMessageId: viewModel.editingMessage?.id,
                    onSelect: { message in
                        guard message.role == .user else { return }
                        viewModel.beginEditing(message: message)
                        isInputFocused = true
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomLeading) {
            if viewModel.isSending {
                Text("The AI is writing a reply…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.95))
                    )
                    .padding(.bottom, 6)
                    .padding(.leading, 12)
            }
        }
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.editingMessage != nil {
                HStack(spacing: 8) {
                    Label("Editing previous message", systemImage: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") {
                        viewModel.cancelEditing()
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            if let errorMessage = viewModel.errorMessage, !viewModel.messages.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    "Example: How much did I spend on dining last month?",
                    text: $viewModel.inputText,
                    axis: .vertical
                )
                .focused($isInputFocused)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

                if viewModel.isSending {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task {
                        await viewModel.sendCurrentMessage()
                        if !viewModel.isSending {
                            isInputFocused = false
                        }
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .clipShape(Circle())
                .accessibilityLabel("Send message")
                .disabled(
                    viewModel.isSending ||
                    viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }
}

private struct ChatMessagesList: View {
    let messages: [AIChatMessage]
    let editingMessageId: UUID?
    let onSelect: (AIChatMessage) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(messages) { message in
                        ChatMessageBubble(
                            message: message,
                            isEditing: editingMessageId == message.id
                        )
                            .id(message.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(message)
                            }
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: messages.last?.id) { id in
                guard let id else { return }
                DispatchQueue.main.async {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct ChatMessageBubble: View {
    let message: AIChatMessage
    let isEditing: Bool

    init(message: AIChatMessage, isEditing: Bool = false) {
        self.message = message
        self.isEditing = isEditing
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                avatar(symbol: "sparkles")
                bubble(alignment: .leading, tint: Color(.secondarySystemBackground), foreground: .primary)
                Spacer(minLength: 8)
            } else {
                Spacer(minLength: 8)
                bubble(alignment: .trailing, tint: Color.indigo.opacity(0.2), foreground: .indigo)
                avatar(symbol: "person.circle.fill")
            }
        }
        .padding(.horizontal, 12)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.indigo.opacity(0.4), lineWidth: isEditing && message.role == .user ? 1.5 : 0)
                .opacity(isEditing && message.role == .user ? 1 : 0)
        )
    }

    @ViewBuilder
    private func bubble(alignment: HorizontalAlignment, tint: Color, foreground: Color) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint)
                        .shadow(color: tint.opacity(0.25), radius: 6, x: 0, y: 2)
                )

            Text(message.createdAt, format: Date.FormatStyle()
                .hour(.twoDigits(amPM: .wide))
                .minute(.twoDigits))
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func avatar(symbol: String) -> some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            .foregroundStyle(message.role == .assistant ? Color.indigo : Color.accentColor)
            .padding(6)
            .background(
                Circle()
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
    }
}

#Preview {
    let sessionController = AppSessionController(sessionStore: InMemorySessionStore())
    sessionController.apply(
        session: AuthSession(
            accessToken: "preview-access",
            refreshToken: "preview-refresh",
            idToken: nil,
            expiresAt: Date().addingTimeInterval(3600),
            userId: "preview-user",
            tokenType: "Bearer"
        )
    )

    return NavigationStack {
        AIChatView(
            viewModel: AIChatViewModel(
                aiService: DemoAIService(),
                sessionController: sessionController
            )
        )
    }
    .environmentObject(sessionController)
}
