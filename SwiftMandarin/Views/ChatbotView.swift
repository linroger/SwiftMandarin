//
//  ChatbotView.swift
//  SwiftMandarin
//
//  AI Chat: write in English or 中文, and every reply comes back in the
//  language being learned, broken into semantic chunks with their readings
//  and meanings — the Translate tab's study view, in a conversation.
//
//  No NavigationStack of its own: it is pushed from Translate and the Study
//  hub on iOS and hosted in the sidebar's detail stack on macOS.
//

import SwiftUI

struct ChatbotView: View {
    @State private var store = ChatbotStore.shared
    @State private var localization = LocalizationManager.shared
    @State private var aiSettings = AIModelSettings.shared

    @State private var draft = ""
    @State private var selectedChunk: ChunkSelection?
    @State private var showHistory = false
    @FocusState private var composerFocused: Bool

    @AppStorage("chatbotShowReadings") private var showReadings = true
    @AppStorage("chatbotShowMeanings") private var showMeanings = true
    @AppStorage("chatbotShowTranslations") private var showTranslations = true

    private static let typingIndicatorID = "chatbot-typing"

    private var learningChinese: Bool { localization.learningIsChinese }

    private var thread: ChatbotThread? { store.currentThread }

    // Typed as LocalizedStringKey rather than written inline: a literal inside
    // a ternary is ambiguous between the localizing and verbatim initializers,
    // and Xcode's extractor does not reliably catalog it.
    private var readingToggleTitle: LocalizedStringKey {
        learningChinese ? "Pinyin" : "IPA"
    }

    private var welcomeMessage: LocalizedStringKey {
        learningChinese
            ? "Ask anything. Every reply comes back in Chinese, split into chunks with pinyin and English meanings, plus a full translation."
            : "Ask anything. Every reply comes back in English, split into chunks with IPA and Chinese meanings, plus a full translation."
    }

    private var messages: [ChatbotMessage] { thread?.messages ?? [] }

    /// Request state lives in the store, per chat, so it survives leaving the
    /// screen and switching chats mid-reply.
    private var isAwaitingHere: Bool {
        store.isAwaitingReply(in: store.currentThreadID)
    }

    /// The banner text: the last failure, or — when the chat ends on a
    /// learner message with no request running and no recorded error (the
    /// app quit mid-reply, for instance) — a plain note, so Retry is always
    /// one tap away instead of the learner sending a duplicate.
    private var currentError: String? {
        if let error = store.currentThreadID.flatMap({ store.replyErrors[$0] }) {
            return error
        }
        if messages.last?.isUser == true, !isAwaitingHere {
            return String(localized: "This message hasn't been answered yet.", bundle: .appLanguage)
        }
        return nil
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if messages.isEmpty && !isAwaitingHere {
                welcome
            } else {
                messageList
            }
        }
        .background(SMTheme.pageBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if let currentError {
                    errorBanner(currentError, dismissible: store.currentThreadID.flatMap { store.replyErrors[$0] } != nil)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                composer
            }
        }
        .navigationTitle("AI Chat")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .sheet(item: $selectedChunk) { selection in
            ChatbotChunkDetailSheet(selection: selection)
                .localizedSurface()
        }
        .sheet(isPresented: $showHistory) {
            ChatbotHistorySheet()
                .localizedSurface()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(.spring(duration: 0.3)) { store.startNewThread() }
                composerFocused = true
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .disabled(thread == nil)
            .accessibilityLabel(Text("New Chat"))
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section("Show") {
                    Toggle(isOn: $showReadings) {
                        Label(readingToggleTitle, systemImage: "textformat.size")
                    }
                    Toggle(isOn: $showMeanings) {
                        Label("Chunk Meanings", systemImage: "text.below.photo")
                    }
                    Toggle(isOn: $showTranslations) {
                        Label("Reply Translations", systemImage: "character.bubble")
                    }
                }
                Button {
                    showHistory = true
                } label: {
                    Label("Chat History", systemImage: "clock.arrow.circlepath")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(Text("Chat options"))
        }
    }

    // MARK: - Welcome

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(SMTheme.heroGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)
                    Text("Chat in English or 中文")
                        .font(.title2.weight(.bold))
                    Text(welcomeMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    providerBadge
                }
                .padding(SMTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .smCardSurface()

                SMSectionHeader(titleKey: "Try asking")
                VStack(spacing: 10) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            send(suggestion)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bubble.left")
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityHidden(true)
                                Text(verbatim: suggestion)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.up.circle")
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .smCardSurface(cornerRadius: 14)
                        }
                        .buttonStyle(.plain)
                        .disabled(!aiSettings.isAnyProviderAvailable)
                    }
                }
            }
            .padding()
            .frame(maxWidth: SMTheme.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var providerBadge: some View {
        if aiSettings.isAnyProviderAvailable {
            Label {
                Text(String(format: String(localized: "Replies by %@", bundle: .appLanguage), aiSettings.effectiveProvider.displayName))
            } icon: {
                Image(systemName: "cpu")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffectCapsuleCompat()
        } else {
            Label("Add an AI provider in Settings → AI to start chatting.", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }

    /// Example openers. Sample learner input rather than interface text, so
    /// they stay verbatim; they follow the learning direction instead.
    private var suggestions: [String] {
        learningChinese
            ? [
                "How do I order a coffee in Chinese?",
                "教我一个常用的成语",
                "What's the difference between 想 and 要?",
                "Tell me about the Mid-Autumn Festival",
            ]
            : [
                "怎么用英语点一杯咖啡？",
                "Teach me a common English idiom",
                "“make” 和 “do” 有什么区别？",
                "介绍一下感恩节",
            ]
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(messages) { message in
                        Group {
                            if message.isUser {
                                userBubble(message)
                            } else {
                                assistantCard(message)
                            }
                        }
                        .id(message.id)
                    }
                    if isAwaitingHere {
                        TypingIndicatorRow()
                            .id(Self.typingIndicatorID)
                    }
                }
                .padding()
                .frame(maxWidth: SMTheme.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: isAwaitingHere) { _, _ in scrollToBottom(proxy) }
            .onChange(of: store.currentThreadID) { _, _ in scrollToBottom(proxy, animated: false) }
            .onAppear { scrollToBottom(proxy, animated: false) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let target: AnyHashable? = isAwaitingHere
            ? AnyHashable(Self.typingIndicatorID)
            : messages.last.map { AnyHashable($0.id) }
        guard let target else { return }
        if animated {
            withAnimation(.spring(duration: 0.35)) { proxy.scrollTo(target, anchor: .bottom) }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }

    private func userBubble(_ message: ChatbotMessage) -> some View {
        HStack {
            Spacer(minLength: 48)
            Text(message.text)
                .font(.body)
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func assistantCard(_ message: ChatbotMessage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(SMTheme.heroGradient, in: Circle())
                    .accessibilityHidden(true)
                Text("AI Chat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if !message.chunksFromModel {
                    Label("Chunked on device", systemImage: "iphone")
                        .labelStyle(.titleAndIcon)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .help(Text("The provider's chunks didn't match its reply, so the reply was split on this device. Meanings aren't available for these chunks."))
                        .accessibilityHint(Text("The provider's chunks didn't match its reply, so the reply was split on this device. Meanings aren't available for these chunks."))
                }
            }

            ChatbotChunkFlow(
                chunks: message.chunks ?? [ChatbotChunk(text: message.text)],
                chinese: message.replyIsChinese,
                showReadings: showReadings,
                showMeanings: showMeanings
            ) { chunk in
                selectedChunk = ChunkSelection(chunk: chunk, chinese: message.replyIsChinese)
            }

            if showTranslations, let translation = message.translation, !translation.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "character.bubble")
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text(translation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            GlassGroupCompat(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        if message.replyIsChinese {
                            SpeechService.speakChinese(message.text)
                        } else {
                            SpeechService.speakEnglish(message.text)
                        }
                    } label: {
                        Label("Speak", systemImage: "speaker.wave.2")
                    }
                    Button {
                        ClipboardService.copy(message.text)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                .font(.footnote.weight(.medium))
                .labelStyle(.titleAndIcon)
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .glassButtonStyleCompat()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The reply floats as Liquid Glass over the page, like the composer;
        // the chips inside are solid tiles, so no glass sits on glass.
        .glassEffectCompat(cornerRadius: 24)
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask anything in English or 中文", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .focused($composerFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(SMTheme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .submitLabel(.send)
                .onSubmit { send(draft) }
                #if os(iOS)
                // A vertical field takes Return as a line break on iOS, so the
                // keyboard's Send key would never fire `onSubmit`; treat a
                // typed trailing newline as Send instead.
                .onChange(of: draft) { _, newValue in
                    guard newValue.hasSuffix("\n") else { return }
                    draft = String(newValue.dropLast())
                    if canSend { send(draft) }
                }
                #endif
            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSend ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel(Text("Send"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffectCompat(cornerRadius: 26)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var canSend: Bool {
        !trimmedDraft.isEmpty && !isAwaitingHere && aiSettings.isAnyProviderAvailable
    }

    private func errorBanner(_ message: String, dismissible: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote)
                .lineLimit(3)
            Spacer(minLength: 8)
            Button("Retry") {
                if let id = store.currentThreadID { requestReply(in: id) }
            }
            .disabled(isAwaitingHere)
            .font(.footnote.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            if dismissible {
                Button {
                    if let id = store.currentThreadID {
                        withAnimation(.spring(duration: 0.3)) { store.clearError(in: id) }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Dismiss"))
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Actions

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAwaitingHere, aiSettings.isAnyProviderAvailable else { return }
        let threadID = store.append(ChatbotMessage(isUser: true, text: trimmed), to: store.currentThreadID)
        store.currentThreadID = threadID
        draft = ""
        requestReply(in: threadID)
    }

    /// Ask for the reply to the chat's last learner message. The reply is
    /// appended to the chat it was asked for, even if the learner has moved
    /// to another chat or left the screen meanwhile.
    private func requestReply(in threadID: UUID) {
        guard let history = store.thread(withID: threadID)?.messages,
              history.last?.isUser == true,
              store.beginReply(in: threadID) else { return }
        let learningIsChinese = localization.learningIsChinese
        let store = store
        Task {
            do {
                let reply = try await ChatbotService.shared.reply(to: history, learningIsChinese: learningIsChinese)
                store.appendReply(reply, to: threadID)
                store.finishReply(in: threadID)
            } catch is CancellationError {
                store.finishReply(in: threadID)
            } catch {
                withAnimation(.spring(duration: 0.3)) {
                    store.finishReply(in: threadID, error: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Chunk flow

/// The reply as chips: reading above, the chunk, and its meaning below —
/// the Translate tab's ruby layout with the gloss made visible.
struct ChatbotChunkFlow: View {
    let chunks: [ChatbotChunk]
    let chinese: Bool
    let showReadings: Bool
    let showMeanings: Bool
    let onTap: (ChatbotChunk) -> Void

    /// The reply's paragraphs: chunks between line-break markers.
    private var paragraphs: [[ChatbotChunk]] {
        var result: [[ChatbotChunk]] = [[]]
        for chunk in chunks {
            if chunk.isLineBreak {
                if !(result.last?.isEmpty ?? true) { result.append([]) }
            } else {
                result[result.count - 1].append(chunk)
            }
        }
        return result.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                FlowLayout(spacing: 6, lineSpacing: 8, stretchesRows: true) {
                    ForEach(Array(ChunkCluster.clusters(paragraph).enumerated()), id: \.offset) { _, cluster in
                        ChunkClusterView(
                            cluster: cluster,
                            chinese: chinese,
                            showReading: showReadings,
                            showMeaning: showMeanings,
                            onTap: onTap
                        )
                    }
                }
            }
        }
    }
}

/// A word chunk with the punctuation that belongs to it. Punctuation is not a
/// chip of its own: a comma or full stop hugs the word before it and an
/// opening quote or bracket the word after it, the way it reads in text,
/// instead of floating in the flow with a gap on either side.
struct ChunkCluster {
    var leading = ""
    var chunk: ChatbotChunk?
    var trailing = ""

    private static let openers: Set<Character> = ["“", "‘", "「", "『", "（", "(", "《", "【", "〈", "[", "{"]

    static func clusters(_ chunks: [ChatbotChunk]) -> [ChunkCluster] {
        var clusters: [ChunkCluster] = []
        var pendingLeading = ""
        // A straight quote has no direction of its own: the first opens, the
        // next closes.
        var straightQuoteOpen = false
        for chunk in chunks {
            guard chunk.isPunctuation else {
                clusters.append(ChunkCluster(leading: pendingLeading, chunk: chunk))
                pendingLeading = ""
                continue
            }
            for character in chunk.text where !character.isWhitespace {
                let opens: Bool
                if character == "\"" {
                    opens = !straightQuoteOpen
                    straightQuoteOpen.toggle()
                } else {
                    opens = openers.contains(character)
                }
                if opens || clusters.isEmpty || !pendingLeading.isEmpty {
                    pendingLeading.append(character)
                } else {
                    clusters[clusters.count - 1].trailing.append(character)
                }
            }
        }
        if !pendingLeading.isEmpty {
            clusters.append(ChunkCluster(leading: pendingLeading))
        }
        return clusters
    }
}

private struct ChunkClusterView: View {
    let cluster: ChunkCluster
    let chinese: Bool
    let showReading: Bool
    let showMeaning: Bool
    let onTap: (ChatbotChunk) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 1) {
            if !cluster.leading.isEmpty {
                punctuation(cluster.leading)
            }
            if let chunk = cluster.chunk {
                ChatbotChunkChip(chunk: chunk, chinese: chinese, showReading: showReading, showMeaning: showMeaning) {
                    onTap(chunk)
                }
            }
            if !cluster.trailing.isEmpty {
                punctuation(cluster.trailing)
            }
        }
    }

    /// Punctuation set on the chip's main text line: the same reading slot
    /// above it and the same top padding, so it sits on the word's baseline.
    private func punctuation(_ text: String) -> some View {
        VStack(spacing: ChatbotChunkChip.lineGap) {
            if showReading {
                Text(verbatim: " ").font(ChatbotChunkChip.readingFont)
            }
            Text(verbatim: text)
                .font(ChatbotChunkChip.wordFont(chinese: chinese))
                .foregroundStyle(.secondary)
        }
        .padding(.top, ChatbotChunkChip.verticalPadding)
        .accessibilityHidden(true)
    }
}

struct ChatbotChunkChip: View {
    let chunk: ChatbotChunk
    let chinese: Bool
    let showReading: Bool
    let showMeaning: Bool
    let action: () -> Void

    @AppStorage("toneColors") private var toneColors: Bool = true

    static let readingFont: Font = .caption.weight(.medium)
    static let meaningFont: Font = .caption2
    static let verticalPadding: CGFloat = 7
    static let lineGap: CGFloat = 2

    static func wordFont(chinese: Bool) -> Font {
        chinese ? .title3.weight(.medium) : .body.weight(.medium)
    }

    /// The gloss wraps within roughly the chunk's own width, so a short word
    /// does not grow a wide chip and a long phrase's gloss is not cut short.
    private var glossWidth: CGFloat {
        let perCharacter: CGFloat = chinese ? 20 : 9
        return min(max(84, CGFloat(chunk.text.count) * perCharacter), 220)
    }

    /// The gloss's width: its own one-line width, capped at `glossWidth`.
    /// Given as an exact width rather than a maximum because the flow layout
    /// measures chips with no width proposal — under that, a capped gloss
    /// reports its one-line height but renders wrapped onto two lines, and the
    /// rows overlapped.
    private var glossFrameWidth: CGFloat {
        #if os(iOS)
        let font = UIFont.preferredFont(forTextStyle: .caption2)
        #else
        let font = NSFont.preferredFont(forTextStyle: .caption2)
        #endif
        let natural = ceil((chunk.meaning as NSString).size(withAttributes: [.font: font]).width) + 2
        return min(natural, glossWidth)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Self.lineGap) {
                // Every chip keeps the reading slot, so the words of a row
                // share one line; the flow stretches the tiles of a row to
                // one height, so a one-line gloss leaves no empty band.
                if showReading {
                    reading
                        .font(Self.readingFont)
                        .lineLimit(1)
                }
                Text(chunk.text)
                    .font(Self.wordFont(chinese: chinese))
                    .foregroundStyle(.primary)
                if showMeaning && !chunk.meaning.isEmpty {
                    Text(chunk.meaning)
                        .font(Self.meaningFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: glossFrameWidth)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, Self.verticalPadding)
            .frame(minWidth: 40, maxHeight: .infinity, alignment: .top)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(ChunkChipButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows details for this chunk"))
    }

    @ViewBuilder
    private var reading: some View {
        if chunk.reading.isEmpty {
            Text(verbatim: " ")
        } else if chinese && toneColors {
            Text(PinyinConverter.coloredPinyin(fromPinyin: chunk.reading))
        } else {
            Text(chunk.reading)
                .foregroundStyle(.secondary)
        }
    }
}

/// A solid, softly raised tile that reads clearly on the glass reply bubble,
/// and gives way under the finger.
private struct ChunkChipButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Always lighter than the glass bubble: the white card fill in light
    /// mode, a soft white lift in dark mode (the dark card fill is darker than
    /// dark glass and made the tiles look recessed).
    private var tileFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.09) : SMTheme.cardFill
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.18) : tileFill)
                    .shadow(color: SMTheme.cardShadow, radius: 2, x: 0, y: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(SMTheme.cardStroke.opacity(0.7), lineWidth: 0.5)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Typing indicator

private struct TypingIndicatorRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .opacity(animating ? 1 : 0.35)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffectCompat(cornerRadius: 20)
            Spacer()
        }
        .onAppear { animating = true }
        .accessibilityElement()
        .accessibilityLabel(Text("Writing a reply"))
    }
}

// MARK: - Chunk detail

struct ChunkSelection: Identifiable {
    let id = UUID()
    let chunk: ChatbotChunk
    let chinese: Bool
}

struct ChatbotChunkDetailSheet: View {
    let selection: ChunkSelection
    @Environment(\.dismiss) private var dismiss
    @State private var savedTerms = SavedTermsStore.shared
    @State private var justSaved = false

    private var chunk: ChatbotChunk { selection.chunk }

    private var saveTitle: LocalizedStringKey {
        alreadySaved || justSaved ? "Saved" : "Save to Vocabulary"
    }

    private var alreadySaved: Bool {
        savedTerms.contains(chinese: chunk.text)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        if !chunk.reading.isEmpty {
                            Group {
                                if selection.chinese {
                                    Text(PinyinConverter.coloredPinyin(fromPinyin: chunk.reading))
                                } else {
                                    Text(chunk.reading).foregroundStyle(.secondary)
                                }
                            }
                            .font(.title3)
                        }
                        Text(chunk.text)
                            .font(.system(size: selection.chinese ? 56 : 40, weight: .medium))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.4)
                            .textSelection(.enabled)
                        if !chunk.meaning.isEmpty {
                            Text(chunk.meaning)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 12)

                    HStack(spacing: 12) {
                        Button {
                            if selection.chinese {
                                SpeechService.speakChinese(chunk.text)
                            } else {
                                SpeechService.speakEnglish(chunk.text)
                            }
                        } label: {
                            Label("Speak", systemImage: "speaker.wave.2")
                        }
                        .glassButtonStyleCompat()

                        Button {
                            ClipboardService.copy(chunk.text)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .glassButtonStyleCompat()
                    }

                    Button {
                        save()
                    } label: {
                        Label(saveTitle, systemImage: alreadySaved || justSaved ? "checkmark" : "bookmark")
                            .frame(maxWidth: .infinity)
                    }
                    .glassProminentButtonStyleCompat()
                    .controlSize(.large)
                    .disabled(alreadySaved || justSaved || chunk.meaning.isEmpty)

                    if chunk.meaning.isEmpty {
                        Text("This chunk has no meaning from the provider, so it can't be saved yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Chunk")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 380)
        #endif
    }

    /// The chunk becomes a vocabulary entry with the learning-language side as
    /// the headword, like every other save in the app.
    private func save() {
        guard !chunk.meaning.isEmpty, !alreadySaved else { return }
        savedTerms.add(
            chinese: chunk.text,
            pinyin: chunk.reading,
            definition: chunk.meaning
        )
        justSaved = true
    }
}

// MARK: - History

struct ChatbotHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = ChatbotStore.shared
    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            Group {
                if store.threads.isEmpty {
                    SMEmptyState(
                        icon: "bubble.left.and.text.bubble.right",
                        titleKey: "No chats yet",
                        messageKey: "Chats you start in AI Chat are kept here."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(store.threads) { thread in
                            Button {
                                store.currentThreadID = thread.id
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(thread.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(thread.dateUpdated, format: .relative(presentation: .named))
                                        Text(verbatim: "·")
                                        Text("\(thread.messages.count) messages")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.remove(thread)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.remove(thread)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chat History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear All", role: .destructive) {
                        confirmDeleteAll = true
                    }
                    .disabled(store.threads.isEmpty)
                }
            }
            .confirmationDialog("Delete all chats?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    store.removeAll()
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }
}

#Preview {
    NavigationStack {
        ChatbotView()
    }
}
