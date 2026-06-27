//
//  ConversationView.swift
//  SwiftMandarin
//
//  AI conversation partner: pick a roleplay scenario, then chat by voice or
//  text with a friendly native speaker of the learning language. Partner
//  bubbles carry learner aids (pinyin for Chinese, a native-language
//  translation disclosure, speech playback); the partner's gentle corrections
//  render as an orange banner under the learner message they refer to.
//
//  Bilingual parity: an English-UI user chats in Mandarin (with pinyin); a
//  中文-UI user chats in English (no pinyin — it isn't native furniture).
//

import SwiftUI

// MARK: - Root

struct ConversationView: View {
    @State private var store = ConversationStore.shared
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.conversations.isEmpty {
                        heroIntro
                        scenarioGrid
                    } else {
                        SMSectionHeader(titleKey: "New conversation")
                        scenarioGrid
                        SMSectionHeader(titleKey: "Continue")
                        recentConversations
                    }
                }
                .padding()
            }
            .background(SMTheme.pageBackground)
            .navigationTitle("Conversation")
            .navigationDestination(for: UUID.self) { id in
                ConversationChatView(conversationID: id)
            }
        }
    }

    // MARK: First-run hero

    private var heroIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Practice speaking with an AI partner")
                .font(.title2.weight(.bold))
            Text("Pick a scene and chat by voice or text. Your partner replies in the language you're learning and gently corrects your mistakes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: Scenario grid

    private var scenarioGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            ForEach(ConversationScenario.allCases) { scenario in
                Button {
                    start(scenario)
                } label: {
                    SMCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: scenario.symbolName)
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(scenario.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .foregroundStyle(scenario.tint)
                            Text(L(scenario.titleKey))
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fitSingleLine()
                            Text(L(scenario.descriptionKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func start(_ scenario: ConversationScenario) {
        let conversation = store.startConversation(scenario: scenario)
        path.append(conversation.id)
    }

    // MARK: Recent conversations

    private var recentConversations: some View {
        LazyVStack(spacing: 10) {
            ForEach(store.conversations) { conversation in
                Button {
                    path.append(conversation.id)
                } label: {
                    SMCard {
                        HStack(spacing: 12) {
                            Image(systemName: conversation.scenario.symbolName)
                                .font(.body)
                                .frame(width: 36, height: 36)
                                .background(conversation.scenario.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .foregroundStyle(conversation.scenario.tint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L(conversation.scenario.titleKey))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .fitSingleLine()
                                Text(preview(for: conversation))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text(conversation.dateUpdated, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation(.spring(duration: 0.35)) {
                            store.remove(conversation)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    /// One-line preview: the first line of the latest message.
    private func preview(for conversation: Conversation) -> String {
        guard let last = conversation.messages.last(where: {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            return L("No messages yet")
        }
        return last.text.components(separatedBy: .newlines).first ?? last.text
    }
}

// MARK: - Scenario tint

private extension ConversationScenario {
    /// Card accent color; a view concern, so it lives here rather than in the
    /// service layer.
    var tint: Color {
        switch self {
        case .freeChat: return .accentColor
        case .cafe: return .brown
        case .directions: return .green
        case .shopping: return .pink
        case .introductions: return .purple
        case .travel: return .blue
        case .doctor: return .red
        }
    }
}

// MARK: - Chat Screen

private struct ConversationChatView: View {
    let conversationID: UUID

    @State private var store = ConversationStore.shared
    @State private var localization = LocalizationManager.shared
    @State private var speech = SpeechRecognitionService.shared

    @State private var draft = ""
    @State private var isAwaitingReply = false
    @State private var errorMessage: String?
    @State private var replyTask: Task<Void, Never>?

    /// Pinyin default follows the learning direction: on for a Chinese
    /// learner, irrelevant (and hidden) for an English learner.
    @State private var showPinyin = LocalizationManager.shared.learningIsChinese

    /// Whether THIS screen started the current recording session, so stray
    /// transcript state from other features never lands in the field.
    @State private var micSessionActive = false
    /// The field's contents when dictation started; the live transcript is
    /// appended to it rather than overwriting typed text.
    @State private var micBaseline = ""
    @State private var micPulsing = false

    private static let typingIndicatorID = "typing-indicator"

    private var conversation: Conversation? {
        store.conversation(withID: conversationID)
    }

    private var isRecordingHere: Bool {
        speech.isRecording && micSessionActive
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesScroll
            if let errorMessage {
                errorBanner(errorMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            inputBar
        }
        .background(SMTheme.pageBackground)
        .navigationTitle(conversation.map { L($0.scenario.titleKey) } ?? L("Conversation"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if localization.learningIsChinese {
                ToolbarItem(placement: .automatic) {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { showPinyin.toggle() }
                    } label: {
                        Text(verbatim: "拼音")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(showPinyin ? Color.accentColor : Color.secondary)
                    }
                    .accessibilityLabel(Text("Show pinyin"))
                }
            }
        }
        .task { greetIfNeeded() }
        .onChange(of: speech.completeTranscript) { _, transcript in
            guard micSessionActive, !transcript.isEmpty else { return }
            draft = micBaseline.isEmpty ? transcript : micBaseline + " " + transcript
        }
        .onChange(of: speech.isRecording) { _, recording in
            if recording && micSessionActive {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    micPulsing = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { micPulsing = false }
            }
        }
        .onDisappear {
            if speech.isRecording && micSessionActive {
                Task { await speech.stopRecording() }
            }
            micSessionActive = false
        }
    }

    // MARK: Messages

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if let conversation {
                        ForEach(conversation.messages) { message in
                            MessageBubble(
                                message: message,
                                learningIsChinese: localization.learningIsChinese,
                                showPinyin: showPinyin
                            )
                            .id(message.id)
                        }
                    }
                    if isAwaitingReply {
                        TypingIndicatorBubble()
                            .id(Self.typingIndicatorID)
                    }
                }
                .padding()
            }
            .onChange(of: conversation?.messages.count ?? 0) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: isAwaitingReply) { _, _ in
                scrollToBottom(proxy)
            }
            .onAppear {
                scrollToBottom(proxy, animated: false)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let target: AnyHashable?
        if isAwaitingReply {
            target = AnyHashable(Self.typingIndicatorID)
        } else {
            target = conversation?.messages.last.map { AnyHashable($0.id) }
        }
        guard let target else { return }
        if animated {
            withAnimation(.spring(duration: 0.35)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }

    // MARK: Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(3)
            Spacer(minLength: 8)
            Button("Retry") {
                requestReply()
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            Button {
                withAnimation(.spring(duration: 0.3)) { errorMessage = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Dismiss"))
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(SMTheme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .submitLabel(.send)
                .onSubmit(send)
            micButton
            sendButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffectCompat(cornerRadius: 26)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var micButton: some View {
        Button {
            Task { await toggleMic() }
        } label: {
            Image(systemName: isRecordingHere ? "mic.fill" : "mic")
                .font(.body.weight(.medium))
                .foregroundStyle(isRecordingHere ? Color.red : Color.accentColor)
                .frame(width: 36, height: 36)
                .background(
                    (isRecordingHere ? Color.red.opacity(0.14) : Color.accentColor.opacity(0.12)),
                    in: Circle()
                )
                .scaleEffect(isRecordingHere && micPulsing ? 1.15 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isRecordingHere ? "Stop recording" : "Dictate"))
    }

    private var sendButton: some View {
        Button(action: send) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(
                    trimmedDraft.isEmpty || isAwaitingReply ? Color.secondary : Color.accentColor
                )
        }
        .buttonStyle(.plain)
        .disabled(trimmedDraft.isEmpty || isAwaitingReply)
        .accessibilityLabel(Text("Send"))
    }

    // MARK: Actions

    private func toggleMic() async {
        if speech.isRecording {
            await speech.stopRecording()
        } else {
            speech.clearTranscripts()
            micBaseline = trimmedDraft
            micSessionActive = true
            do {
                try await speech.startRecording(
                    language: localization.learningIsChinese ? .chinese : .english
                )
            } catch {
                micSessionActive = false
                withAnimation(.spring(duration: 0.3)) {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func send() {
        let text = trimmedDraft
        guard !text.isEmpty, !isAwaitingReply, conversation != nil else { return }
        if speech.isRecording && micSessionActive {
            Task { await speech.stopRecording() }
        }
        micSessionActive = false
        draft = ""
        store.append(message: ConversationMessage(isUser: true, text: text), to: conversationID)
        requestReply()
    }

    /// Kick off the scenario greeting when the conversation is brand new.
    /// Uses the same `reply()` path with empty history, so a failed greeting
    /// is retryable from the error banner (and re-attempted by `.task` when
    /// the screen is revisited).
    private func greetIfNeeded() {
        guard let conversation, conversation.messages.isEmpty, !isAwaitingReply else { return }
        requestReply()
    }

    /// Ask the partner for the next turn based on the store's CURRENT history
    /// (which ends with the learner's latest message, or is empty for the
    /// greeting). Retry re-invokes this without duplicating the user message.
    private func requestReply() {
        withAnimation(.spring(duration: 0.3)) { errorMessage = nil }
        isAwaitingReply = true
        replyTask?.cancel()
        replyTask = Task {
            guard let current = store.conversation(withID: conversationID) else {
                isAwaitingReply = false
                return
            }
            do {
                let reply = try await ConversationService.shared.reply(
                    scenario: current.scenario,
                    history: current.messages,
                    learningIsChinese: localization.learningIsChinese
                )
                guard !Task.isCancelled else { return }
                // Greeting race guard: if the screen was left and re-entered
                // while the first greeting request was in flight, a second
                // greeting may already have landed — drop this duplicate.
                if current.messages.isEmpty,
                   let latest = store.conversation(withID: conversationID),
                   !latest.messages.isEmpty {
                    isAwaitingReply = false
                    return
                }
                store.append(
                    message: ConversationMessage(
                        isUser: false,
                        text: reply.reply,
                        pinyin: reply.pinyin,
                        translation: reply.translation.isEmpty ? nil : reply.translation
                    ),
                    to: conversationID
                )
                if let feedback = reply.feedback,
                   let lastUser = current.messages.last(where: { $0.isUser }) {
                    store.attachFeedback(feedback, toMessageID: lastUser.id, in: conversationID)
                }
                isAwaitingReply = false
            } catch {
                guard !Task.isCancelled else { return }
                isAwaitingReply = false
                withAnimation(.spring(duration: 0.3)) {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ConversationMessage
    let learningIsChinese: Bool
    let showPinyin: Bool

    @State private var showTranslation = false

    var body: some View {
        if message.isUser {
            userBubble
        } else {
            partnerBubble
        }
    }

    // MARK: Partner (leading, material)

    private var partnerBubble: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.text)
                        .font(learningIsChinese ? .title3 : .body)
                        .textSelection(.enabled)
                    Button {
                        SpeechService.speakAuto(message.text)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Play audio"))
                }
                if learningIsChinese, showPinyin,
                   let pinyin = message.pinyin, !pinyin.isEmpty {
                    Text(PinyinConverter.coloredPinyin(fromPinyin: pinyin))
                        .font(.subheadline)
                }
                if let translation = message.translation, !translation.isEmpty {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { showTranslation.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .rotationEffect(.degrees(showTranslation ? 90 : 0))
                            Text("Translation")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    if showTranslation {
                        Text(translation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 40)
        }
    }

    // MARK: User (trailing, accent) + feedback banner

    private var userBubble: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 40)
            VStack(alignment: .trailing, spacing: 6) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                if let feedback = message.feedback, !feedback.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                        Text(feedback)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(Color.orange)
                    .padding(10)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Typing Indicator

/// Three softly blinking dots in a partner-style bubble while the reply is
/// being generated.
private struct TypingIndicatorBubble: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .opacity(animating ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.18),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 40)
        }
        .onAppear { animating = true }
        .accessibilityLabel(Text("Partner is typing"))
    }
}
