import SwiftUI

struct AIChatView: View {
    @StateObject private var viewModel: AIChatViewModel
    @FocusState private var isInputFocused: Bool

    init(viewModel: AIChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            content

            inputBar
        }
        .padding(20)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("AI Chat Assistant")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Retry") {
                    Task { await viewModel.retry() }
                }
                .disabled(viewModel.isLoadingHistory)
            }
        }
        .task {
            await viewModel.loadInitialMessages()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自然言語で質問してください。SafepocketのAIが最新の支出データから回答を生成します。")
                .font(.title3.weight(.semibold))

            Text("支出データからの洞察や過去のアドバイスを会話形式で確認できます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var content: some View {
        Group {
            if viewModel.isLoadingHistory && viewModel.messages.isEmpty {
                ProgressView("Connecting…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let errorMessage = viewModel.errorMessage, viewModel.messages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.9))
                    )
                    .padding(.bottom, 8)
                    .padding(.leading, 16)
            }
        }
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            TextField(
                "Example: How much did I spend on dining last month?",
                text: $viewModel.inputText,
                axis: .vertical
            )
            .focused($isInputFocused)
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...4)

            HStack(spacing: 12) {
                Spacer()
                if viewModel.isSending {
                    ProgressView()
                }
                Button("Send") {
                    Task {
                        await viewModel.sendCurrentMessage()
                        if !viewModel.isSending {
                            isInputFocused = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
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
                .strokeBorder(Color.indigo, lineWidth: isEditing && message.role == .user ? 1.5 : 0)
                .opacity(isEditing && message.role == .user ? 1 : 0)
        )
    }

    @ViewBuilder
    private func bubble(alignment: HorizontalAlignment, tint: Color, foreground: Color) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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
            .padding(4)
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
