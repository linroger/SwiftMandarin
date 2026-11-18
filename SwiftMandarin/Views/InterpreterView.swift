//
//  InterpreterView.swift
//  SwiftMandarin
//
//  The Interpreter: two people, two languages, two buttons. Hold a button
//  while you speak; let go, and the app says it in the other language.
//
//  The screen is a thin layer over `SpeechTranslationCoordinator`. It shows
//  what is installed and offers the download, lists the conversation, and
//  turns touches, clicks and the Space bar into press and release.
//
//  No NavigationStack of its own: it is pushed from Translate and the Study
//  hub on iOS and hosted in the sidebar's detail stack on macOS.
//

import SwiftUI
import Translation

struct InterpreterView: View {
    var body: some View {
        Group {
            if #available(iOS 26.0, macOS 26.0, *) {
                InterpreterScreen()
            } else {
                // The on-device recognizer the Interpreter is built on does
                // not exist before these releases.
                ScrollView {
                    SMEmptyState(
                        icon: "person.2.wave.2.fill",
                        titleKey: "Interpreter",
                        messageKey: "The Interpreter needs iOS 26 or macOS 26 or later."
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
                .smPageBackground()
            }
        }
        .navigationTitle("Interpreter")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct InterpreterScreen: View {
    @State private var coordinator = InterpreterRuntime.coordinator
    @State private var preferences = AppPreferences.shared
    @State private var aiSettings = AIModelSettings.shared

    /// Set to make the system offer the translation languages, and cleared
    /// once it has. Only a view can host that request.
    @State private var translationRequest: TranslationSession.Configuration?
    /// The button that the Space bar presses.
    @State private var keyboardDirection: TranslationDirection = .englishToChinese
    /// The press a Space bar that is down right now is holding.
    @State private var spaceBarPress: InterpreterPress?
    /// The press each hold button's finger or pointer is holding.
    @State private var buttonPresses: [TranslationDirection: InterpreterPress] = [:]
    /// A key has been used on this screen, so the key cap is worth showing
    /// where a keyboard is not a given.
    @State private var hasUsedKeyboard = false
    /// This screen has told the coordinator it is on display. Appear and
    /// disappear are not promised to come in pairs.
    @State private var isActivated = false
    /// Whether a better Mandarin system voice is installed. Looked up when
    /// the screen appears and when the app comes back, which is when it can
    /// have changed.
    @State private var hasEnhancedMandarinVoice = true
    @FocusState private var hasKeyboardFocus: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let conversationEndID = "interpreter-conversation-end"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    readinessBanner
                    voiceNote

                    if coordinator.turns.isEmpty, !showsLiveCard {
                        emptyState
                    }
                    ForEach(coordinator.turns) { turn in
                        InterpreterTurnCard(
                            turn: turn,
                            isSpeaking: coordinator.speakingTurnID == turn.id,
                            canReplay: canReplay,
                            onReplay: { coordinator.replay(turn.id) },
                            onStop: { coordinator.stopSpeaking() }
                        )
                        .id(turn.id)
                    }
                    if showsLiveCard {
                        liveCard
                    }
                    // What the list scrolls to: a little below the last
                    // card, so the card clears the bar under it.
                    Color.clear
                        .frame(height: 2)
                        .id(Self.conversationEndID)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: SMTheme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding()
            }
            #if !os(visionOS)
            // Turns that scroll under the hold buttons fade out behind them,
            // as they do behind the navigation bar.
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            #endif
            .onChange(of: coordinator.turns.count) { _, _ in
                scrollToEnd(proxy)
            }
            .onChange(of: coordinator.liveTranscript) { _, _ in
                scrollToEnd(proxy)
            }
            // A note above the buttons makes the bar taller; keep the latest
            // turn above it.
            .onChange(of: showsNoteAboveButtons) { _, _ in
                scrollToEnd(proxy)
            }
            // The card for a press appears below the last turn, before there
            // is any transcript to scroll for.
            .onChange(of: showsLiveCard) { _, _ in
                scrollToEnd(proxy)
            }
            // The conversation outlives the screen, so coming back to it
            // opens on the latest turn, not the first.
            .onAppear {
                scrollToEnd(proxy, animated: false)
            }
        }
        .smPageBackground()
        // A bar, not a plain inset, so the scroll view knows the buttons are
        // there and applies its edge effect beneath them.
        .safeAreaBar(edge: .bottom, spacing: 0) {
            controls
        }
        .toolbar { toolbarContent }
        .translationTask(translationRequest) { session in
            // The system's own sheet asks for permission and downloads the
            // languages. Whatever the person chooses, look again afterwards.
            try? await session.prepareTranslation()
            coordinator.translationLanguagesPrepared()
            // Done with this request. Left in place it would run again every
            // time the screen came back, and put the system's sheet up
            // without anyone asking.
            translationRequest = nil
        }
        .onChange(of: coordinator.translationDownloadRequests) { _, _ in
            requestTranslationLanguages()
        }
        .onAppear {
            if !isActivated {
                isActivated = true
                coordinator.activate()
            }
            hasKeyboardFocus = true
            refreshSystemVoiceTip()
            // What the Voice menu shows is now a choice of its own.
            preferences.settleInterpreterVoiceEngine()
        }
        .onDisappear {
            // A press this screen was holding has nobody left to release it.
            // With another Interpreter window open the coordinator carries
            // on, so the press is given up here, and only this screen's.
            giveUpOwnPresses()
            if isActivated {
                isActivated = false
                coordinator.deactivate()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                coordinator.sceneBecameActive()
                refreshSystemVoiceTip()
            case .inactive:
                endHeldPress()
            case .background:
                spaceBarPress = nil
                coordinator.sceneEnteredBackground()
            @unknown default:
                break
            }
        }
        // A mouse button or a key held when the window stops being the
        // active one may never report its release here, so the press ends now.
        .onChange(of: appearsActive) { _, isActive in
            if !isActive {
                endHeldPress()
            }
        }
        // The same for the Space bar when the keyboard's attention moves to
        // another control: its key-up will go there, not here.
        .onChange(of: hasKeyboardFocus) { _, hasFocus in
            if !hasFocus, spaceBarPress != nil {
                endHeldPress()
            }
        }
        .onChange(of: coordinator.hint) { _, hint in
            // The hint is on screen for three seconds; say it as well.
            if let hint {
                AccessibilityNotification.Announcement(hint.message).post()
            }
        }
        .onChange(of: coordinator.state) { _, state in
            if case .error(let error) = state {
                AccessibilityNotification.Announcement(error.message).post()
            }
        }
        .focusable()
        .focused($hasKeyboardFocus)
        .focusEffectDisabled()
        // Every phase is handled, including the repeats a held key sends:
        // left unhandled they reach the system, which answers each one with
        // its alert sound, into an open microphone.
        .onKeyPress(.space, phases: .all) { press in
            switch press.phase {
            case .down:
                hasUsedKeyboard = true
                // Kept only when the press was taken. A key that goes down
                // while a button is being held is ignored, and must not end
                // that button's turn when it comes up.
                if let press = coordinator.pressDown(keyboardDirection) {
                    spaceBarPress = press
                }
            case .up:
                if let press = spaceBarPress {
                    spaceBarPress = nil
                    coordinator.pressUp(press)
                }
            default:
                break
            }
            return .handled
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
            // Not while Space is down: the release has to reach the button
            // the press went to.
            guard spaceBarPress == nil, !coordinator.state.isListening else { return .handled }
            hasUsedKeyboard = true
            keyboardDirection = press.key == .leftArrow ? .englishToChinese : .chineseToEnglish
            return .handled
        }
    }

    /// A press that can no longer be trusted to end by itself ends now.
    private func endHeldPress() {
        spaceBarPress = nil
        coordinator.sceneBecameInactive()
    }

    /// Gives up the presses this screen's own inputs are holding, and no
    /// others.
    private func giveUpOwnPresses() {
        if let press = spaceBarPress {
            coordinator.cancelPress(press)
        }
        for press in buttonPresses.values {
            coordinator.cancelPress(press)
        }
        spaceBarPress = nil
        buttonPresses.removeAll()
    }

    private func refreshSystemVoiceTip() {
        hasEnhancedMandarinVoice = SpeechService.hasEnhancedSystemVoice(forLanguage: "zh-CN")
    }

    // MARK: - Conversation

    private var showsLiveCard: Bool {
        switch coordinator.state {
        case .listening, .finalizingTranscript, .translating: return true
        case .idle, .preparingModels, .speaking, .error: return false
        }
    }

    private var canReplay: Bool {
        switch coordinator.state {
        case .idle, .error, .speaking: return true
        case .preparingModels, .listening, .finalizingTranscript, .translating: return false
        }
    }

    /// An error or a hint is showing above the hold buttons.
    private var showsNoteAboveButtons: Bool {
        if case .error = coordinator.state { return true }
        return coordinator.hint != nil
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy, animated: Bool = true) {
        // With no conversation there is nothing to follow, and scrolling
        // would only push the banners at the top out of view.
        guard !coordinator.turns.isEmpty || showsLiveCard else { return }
        withAnimation(animated ? .easeOut(duration: 0.2) : nil) {
            proxy.scrollTo(Self.conversationEndID, anchor: .bottom)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            SMEmptyState(
                icon: "person.2.wave.2.fill",
                titleKey: "Speak, and hear it translated",
                messageKey: "Hold a button while you speak and let go when you finish. The Interpreter says it aloud in the other language."
            )
            if showsSystemVoiceTip {
                Text("Tip: the system's Mandarin voice sounds more natural once an Enhanced voice is downloaded in the system's voice settings. A MiniMax voice is the other choice, in the options menu.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 28)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The system voice is selected and the best installed Mandarin voice is
    /// the compact default, which is the least natural-sounding option.
    private var showsSystemVoiceTip: Bool {
        preferences.interpreterVoiceEngine == .system && !hasEnhancedMandarinVoice
    }

    /// The transcript of the turn in progress: finalized words in the normal
    /// color, the tail the recognizer may still rewrite in a lighter one.
    private var liveTranscriptText: AttributedString {
        let snapshot = coordinator.liveTranscript
        let whole = snapshot.text
        guard !snapshot.volatile.isEmpty, whole.hasPrefix(snapshot.finalized) else {
            return AttributedString(whole)
        }
        var tail = AttributedString(String(whole.dropFirst(snapshot.finalized.count)))
        tail.foregroundColor = .secondary
        return AttributedString(snapshot.finalized) + tail
    }

    private var liveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let direction = coordinator.activeDirection {
                Text(verbatim: direction.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if coordinator.liveTranscript.isEmpty {
                Text("Listening…")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            } else {
                Text(liveTranscriptText)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            switch coordinator.state {
            case .finalizingTranscript:
                progressLine("Finishing…")
            case .translating:
                progressLine("Translating…")
            default:
                EmptyView()
            }
        }
        .padding(SMTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .smCardSurface()
        .accessibilityElement(children: .combine)
    }

    private func progressLine(_ title: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Readiness

    @ViewBuilder
    private var readinessBanner: some View {
        let readiness = coordinator.readiness
        if case .preparingModels(let progress) = coordinator.state {
            banner(icon: "arrow.down.circle.fill", tint: .accentColor) {
                Text("Downloading the speech models…")
                    .font(.subheadline.weight(.medium))
                if let progress {
                    ProgressView(value: progress)
                        .accessibilityLabel(Text("Speech model download"))
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        } else if readiness.isUnknown {
            banner(icon: "hourglass", tint: .secondary) {
                Text("Checking what is installed…")
                    .font(.subheadline)
            }
        } else if readiness.hasUnsupportedAsset {
            banner(icon: "exclamationmark.triangle.fill", tint: .orange) {
                Text("This device cannot recognize or translate English and Chinese on its own, so the Interpreter is not available here.")
                    .font(.subheadline)
            }
        } else if readiness.isDownloading {
            // A download that is already under way, started before this
            // screen opened. The coordinator looks again until it is done.
            banner(icon: "arrow.down.circle.fill", tint: .accentColor) {
                Text("Downloading the speech models…")
                    .font(.subheadline.weight(.medium))
                ProgressView()
                    .controlSize(.small)
            }
        } else if readiness.needsDownload {
            banner(icon: "arrow.down.circle.fill", tint: .accentColor) {
                Text("The Interpreter needs the English and Chinese speech models and translation languages on this device. They are downloaded once and then work offline.")
                    .font(.subheadline)
                Button {
                    coordinator.downloadModels()
                } label: {
                    Label("Download", systemImage: "arrow.down.to.line")
                }
                .glassProminentButtonStyleCompat()
                .controlSize(.small)
            }
        } else if readiness.microphone == .denied {
            banner(icon: "mic.slash.fill", tint: .orange) {
                Text("Microphone access is turned off for SwiftMandarin.")
                    .font(.subheadline)
                Button("Open Settings") {
                    openSystemSettings()
                }
                .glassButtonStyleCompat()
                .controlSize(.small)
            }
        }

        if readiness.translation == .simulatorMock {
            banner(icon: "hammer.fill", tint: .secondary) {
                Text("Simulator: speech recognition and translation are stand-ins here, and say so. Speech output is real.")
                    .font(.footnote)
            }
        }
    }

    /// MiniMax is selected but cannot be used yet.
    @ViewBuilder
    private var voiceNote: some View {
        if preferences.interpreterVoiceEngine == .miniMax,
           aiSettings.apiKey(for: .minimax).isEmpty {
            banner(icon: "key.fill", tint: .orange) {
                Text("The MiniMax voice needs an API key. Add one in AI Audio settings, or choose the system voice.")
                    .font(.footnote)
            }
        }
    }

    private func banner<Content: View>(
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SMTheme.cardPadding)
        .smCardSurface()
    }

    private func requestTranslationLanguages() {
        // A new configuration each time; the last one was cleared when its
        // request finished.
        translationRequest = TranslationSession.Configuration(
            source: TranslationDirection.englishToChinese.sourceLanguage,
            target: TranslationDirection.englishToChinese.targetLanguage
        )
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            if case .error(let error) = coordinator.state {
                errorRow(error)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let hint = coordinator.hint {
                Text(verbatim: hint.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffectCapsuleCompat()
                    .transition(.opacity)
            }

            // Side by side, or one above the other at the largest text
            // sizes, where half the width cannot hold a title.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                holdButton(for: .englishToChinese)
                holdButton(for: .chineseToEnglish)
            }
            // Both as tall as the taller one: the keyboard hint makes one
            // button's caption a little taller than the other's.
            .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.hint)
        .animation(.easeInOut(duration: 0.2), value: coordinator.state)
        .frame(maxWidth: SMTheme.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private func holdButton(for direction: TranslationDirection) -> some View {
        HoldToSpeakButton(
            copy: direction == .englishToChinese ? .english : .chinese,
            caption: direction == .englishToChinese ? "English → 中文" : "中文 → English",
            tint: direction.interpreterTint,
            phase: phase(for: direction),
            showsKeyboardHint: showsKeyboardHints && keyboardDirection == direction,
            onPress: {
                keyboardDirection = direction
                // Kept only when the press was taken; see the Space bar.
                if let press = coordinator.pressDown(direction) {
                    buttonPresses[direction] = press
                }
            },
            // Each button hands back the press it was given, and the
            // coordinator ends that press and no other.
            onRelease: {
                if let press = buttonPresses.removeValue(forKey: direction) {
                    coordinator.pressUp(press)
                }
            }
        )
    }

    private func phase(for direction: TranslationDirection) -> HoldToSpeakButton.Phase {
        guard coordinator.canStartTurn else { return .unavailable }
        // Down, and waiting for the previous press to be settled.
        if coordinator.pendingPressDirection == direction { return .starting }
        let isMine = coordinator.activeDirection == direction
        switch coordinator.state {
        case .listening:
            // The other button cannot take the microphone until this press ends.
            guard isMine else { return .unavailable }
            return coordinator.isMicrophoneLive ? .recording : .starting
        case .finalizingTranscript, .translating:
            return isMine ? .processing : .ready
        case .speaking:
            return isMine ? .speaking : .ready
        case .idle, .error, .preparingModels:
            return .ready
        }
    }

    /// The Space bar hint is shown where a keyboard is always present, and
    /// elsewhere once a key has been used, so that an arrow key pressed on an
    /// iPad's keyboard visibly moves it.
    private var showsKeyboardHints: Bool {
        #if os(macOS)
        true
        #else
        hasUsedKeyboard
        #endif
    }

    private func errorRow(_ error: UserFacingError) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text(verbatim: error.message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let title = recoveryTitle(for: error.recovery) {
                Button(title) {
                    if error.recovery == .openSettings {
                        openSystemSettings()
                    }
                    coordinator.performRecovery()
                }
                .glassButtonStyleCompat()
                .controlSize(.small)
            }
            Button {
                coordinator.dismissError()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Dismiss"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffectCompat(cornerRadius: 14, tint: Color.red.opacity(0.3))
        .accessibilityElement(children: .contain)
    }

    private func recoveryTitle(for recovery: UserFacingError.Recovery) -> LocalizedStringKey? {
        switch recovery {
        case .none: return nil
        case .openSettings: return "Open Settings"
        case .downloadModels: return "Download"
        case .retry: return "Try Again"
        }
    }

    private func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                // Each choice is a row that names what it chooses and shows
                // the current answer. Laid out in the menu itself, the
                // options appear with nothing to say what they are for.
                Picker("Reply Voice", selection: $preferences.interpreterVoiceEngine) {
                    Label("System Voice", systemImage: "waveform")
                        .tag(SpeechVoiceEngine.system)
                    Label("MiniMax AI Voice", systemImage: "sparkles")
                        .tag(SpeechVoiceEngine.miniMax)
                }
                .pickerStyle(.menu)
                // Offered only where the device has two translation models
                // to choose between.
                if coordinator.offersTranslationChoice {
                    Picker("Translation", selection: $preferences.interpreterTranslationQuality) {
                        Text("Automatic").tag(InterpreterTranslationQuality.automatic)
                        Text("Natural").tag(InterpreterTranslationQuality.natural)
                        Text("Fast").tag(InterpreterTranslationQuality.fast)
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    Button(role: .destructive) {
                        coordinator.clearConversation()
                    } label: {
                        Label("Clear Conversation", systemImage: "trash")
                    }
                    .disabled(coordinator.turns.isEmpty || coordinator.state.isBusy)
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .accessibilityLabel(Text("Interpreter Options"))
            .help(Text("Interpreter Options"))
        }
    }
}

// MARK: - Speaker colours

private extension TranslationDirection {
    /// The colour of the speaker whose language this direction listens to:
    /// their button, and the edge of their turns. The Mandarin speaker's is
    /// a deeper teal than the system's, which is too light to carry the
    /// button's white text (about 2.5 to 1; this one is about 5 to 1).
    var interpreterTint: Color {
        switch self {
        case .englishToChinese: return .indigo
        case .chineseToEnglish: return Color(red: 0.0, green: 0.47, blue: 0.55)
        }
    }
}

// MARK: - Turn card

/// One finished exchange: what was said, what it means, and a way to hear
/// the translation again.
private struct InterpreterTurnCard: View {
    let turn: InterpreterTurn
    let isSpeaking: Bool
    let canReplay: Bool
    let onReplay: () -> Void
    let onStop: () -> Void

    @State private var didCopy = false

    private var tint: Color {
        turn.direction.interpreterTint
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Which speaker this turn belongs to, matching their button.
            Capsule()
                .fill(tint)
                .frame(width: 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(verbatim: turn.direction.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if turn.spokenWith == .miniMax {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("MiniMax AI Voice"))
                    }
                }

                Text(verbatim: turn.sourceText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(verbatim: turn.translatedText)
                    .font(.title3.weight(.medium))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let failure = turn.speechFailure {
                    Label {
                        Text(verbatim: failure)
                    } icon: {
                        Image(systemName: "speaker.slash.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                GlassGroupCompat(spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            if isSpeaking {
                                onStop()
                            } else {
                                onReplay()
                            }
                        } label: {
                            if isSpeaking {
                                Label("Stop", systemImage: "stop.fill")
                            } else {
                                Label("Replay", systemImage: "speaker.wave.2.fill")
                            }
                        }
                        .disabled(!isSpeaking && !canReplay)

                        Button {
                            ClipboardService.copy(turn.translatedText)
                            didCopy = true
                        } label: {
                            if didCopy {
                                Label("Copied", systemImage: "checkmark")
                            } else {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                    }
                    .glassButtonStyleCompat()
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
            }
        }
        .padding(SMTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .smCardSurface()
        .task(id: didCopy) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }
}

#Preview {
    NavigationStack {
        InterpreterView()
    }
}
