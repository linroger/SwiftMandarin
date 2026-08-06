//
//  MultimodalAudioInputView.swift
//  SwiftMandarin
//
//  Local audio recording/import, preview, and Apple Speech transcription for
//  the Multimodal tab. Translation remains owned by PhotoTranslateView so the
//  same editor, analysis, and translation paths are reused.
//

import SwiftUI
import UniformTypeIdentifiers

enum MultimodalInputMode: String, CaseIterable, Identifiable {
    case imageAndText
    case audio

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .imageAndText: return "Image & Text"
        case .audio: return "Audio"
        }
    }

    var iconName: String {
        switch self {
        case .imageAndText: return "photo.on.rectangle.angled"
        case .audio: return "waveform"
        }
    }
}

enum MultimodalAudioAction: Sendable, Equatable {
    case transcribeToEditor
    case translateAudio
}

private enum AudioInputOperation {
    case transcribing
    case translating

    var progressTitle: LocalizedStringKey {
        switch self {
        case .transcribing: return "Transcribing audio…"
        case .translating: return "Transcribing, then translating…"
        }
    }
}

private enum AudioStatusKind {
    case success
    case neutral
    case inProgress
}

@MainActor
struct MultimodalAudioInputView: View {
    let onResult: @MainActor (
        _ transcript: String,
        _ language: SpeechRecognitionLanguage,
        _ action: MultimodalAudioAction
    ) async throws -> Void

    @State private var captureService = AudioCaptureService()
    @State private var transcriptionService = AudioTranscriptionService()
    @State private var preferences = AppPreferences.shared
    @State private var aiSettings = AIModelSettings.shared
    /// Set when an Apple Speech attempt failed and an AI provider could take
    /// over, so the learner is offered the switch instead of a dead end.
    @State private var offerAIFallback = false
    @State private var selectedAudio: PreparedAudioFile?
    @AppStorage("multimodal_audio_recognition_language")
    private var savedRecognitionLanguage = ""
    @State private var showAudioImporter = false
    @State private var isPreparingFile = false
    @State private var operation: AudioInputOperation?
    @State private var operationTask: Task<Void, Never>?
    @State private var operationID: UUID?
    @State private var preparationTask: Task<Void, Never>?
    @State private var preparationID: UUID?
    @State private var recordingLimitTask: Task<Void, Never>?
    @State private var recordingLimitID: UUID?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var statusKind: AudioStatusKind = .success

    private var isBusy: Bool {
        preparationID != nil
            || isPreparingFile
            || captureService.isStartingRecording
            || operation != nil
    }

    private var recognitionLanguage: SpeechRecognitionLanguage {
        if let saved = SpeechRecognitionLanguage(rawValue: savedRecognitionLanguage) {
            return saved
        }
        return preferences.learnerMode.defaultDirection == .englishToChinese
            ? .english
            : .chinese
    }

    private var recognitionLanguageBinding: Binding<SpeechRecognitionLanguage> {
        Binding(
            get: { recognitionLanguage },
            set: { savedRecognitionLanguage = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 10) {
                Button {
                    toggleRecording()
                } label: {
                    Label(
                        captureService.isRecording ? "Stop Recording" : "Record Audio",
                        systemImage: captureService.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                    )
                    .fitSingleLine(0.72)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(captureService.isRecording ? .red : .accentColor)
                .disabled(isBusy)
                .accessibilityHint(
                    captureService.isRecording
                        ? "Stops and prepares the current recording"
                        : "Requests microphone access and begins a new recording"
                )

                Button {
                    showAudioImporter = true
                } label: {
                    Label(selectedAudio == nil ? "Choose Audio File" : "Replace File", systemImage: "folder.badge.plus")
                        .fitSingleLine(0.72)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy || captureService.isRecording)
                .accessibilityHint("Choose a local audio file up to 60 seconds and 100 megabytes")
            }

            if captureService.isStartingRecording {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Starting recording…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            } else if captureService.isRecording {
                recordingIndicator
            }

            if isPreparingFile {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Preparing audio preview…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            } else if let selectedAudio {
                selectedAudioCard(selectedAudio)
            } else if !captureService.isRecording {
                noAudioPlaceholder
            }

            recognitionControls

            if let operation {
                operationProgress(operation)
            } else {
                actionButtons
            }

            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(String(localized: "Audio error:", bundle: .appLanguage) + " " + errorMessage)

                    if offerAIFallback {
                        HStack(spacing: 8) {
                            Button {
                                retryWithAI(.transcribeToEditor)
                            } label: {
                                Label("Retry with AI", systemImage: "sparkles")
                                    .fitSingleLine(0.7)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button {
                                retryWithAI(.translateAudio)
                            } label: {
                                Label("Retry & Translate", systemImage: "translate")
                                    .fitSingleLine(0.7)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .disabled(selectedAudio == nil)
                    }
                }
            } else if let statusMessage {
                Label(statusMessage, systemImage: statusSymbol)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(privacyNotice, systemImage: "hand.raised.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
        // Keeping this importer on the child pane prevents it from competing
        // with PhotoTranslateView's independent image importer.
        .fileImporter(
            isPresented: $showAudioImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        .onChange(of: captureService.completedRecordingURL) { _, newURL in
            guard newURL != nil, let url = captureService.takeCompletedRecordingURL() else { return }
            cancelRecordingLimit()
            prepareRecording(at: url)
            statusMessage = String(localized: "Recording stopped because read-aloud started. Your clip is being prepared.", bundle: .appLanguage)
            statusKind = .neutral
        }
        .onChange(of: captureService.playbackErrorMessage) { _, newMessage in
            guard let newMessage else { return }
            errorMessage = newMessage
            captureService.clearPlaybackError()
        }
        .onDisappear {
            cancelPreparation()
            cancelOperation(showStatus: false)
            cancelRecordingLimit()
            captureService.stopAll()
            if let selectedAudio {
                AudioInputFileStore.remove(selectedAudio.url)
            }
            transcriptionService.cancel()
        }
    }

    /// The privacy line has to track the engine: the two choices send the audio
    /// to different places, and the learner is picking between them right above.
    private var privacyNotice: LocalizedStringKey {
        switch aiSettings.transcriptionEngine {
        case .appleSpeech:
            return "Transcription uses Apple Speech and prefers on-device recognition when available. When on-device recognition is unavailable, Apple may process the audio using its speech service. Your selected audio is not sent to MiniMax; Translate Audio may send the transcript to your configured translation provider."
        case .aiProvider:
            return "AI transcription uploads the selected audio to your configured AI provider, which usually bills for it. The audio is not sent to MiniMax. Translate Audio also sends the transcript to your translation provider. Switch to Apple Speech to keep the audio on device."
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label("Audio Input", systemImage: "waveform.badge.mic")
                .font(.headline)
            Spacer()
            Text("Record or import")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            // This indicator is intentionally static: it remains clear without
            // a pulsing animation, including when Reduce Motion is enabled.
            Image(systemName: "record.circle.fill")
                .foregroundStyle(.red)
            Text("Recording… Tap Stop Recording when finished.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recording in progress")
    }

    private var noAudioPlaceholder: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.slash")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No audio selected")
                    .font(.subheadline.weight(.medium))
                Text("Record a clip or choose an M4A, MP3, WAV, AIFF, or CAF file up to 60 seconds and 100 MB.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func selectedAudioCard(_ audio: PreparedAudioFile) -> some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    do {
                        try await captureService.togglePlayback(of: audio.url)
                        errorMessage = nil
                    } catch is CancellationError {
                        // A newer audio action intentionally replaced startup.
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                Image(systemName: captureService.playingURL == audio.url ? "stop.fill" : "play.fill")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .disabled(isBusy || captureService.isRecording)
            .accessibilityLabel(captureService.playingURL == audio.url ? "Stop preview" : "Play preview")

            VStack(alignment: .leading, spacing: 3) {
                Text(audio.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(metadataDescription(for: audio))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                removeSelectedAudio()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .disabled(isBusy || captureService.isRecording)
            .accessibilityLabel("Remove selected audio")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.045))
        )
        .accessibilityElement(children: .contain)
    }

    private var recognitionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Audio Language", systemImage: "character.bubble")
                        .font(.subheadline)
                    Text("Choose the language spoken in the recording.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Audio Language", selection: recognitionLanguageBinding) {
                    ForEach(SpeechRecognitionLanguage.allCases, id: \.rawValue) { language in
                        Text(localizedTitle(for: language)).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(isBusy || captureService.isRecording)
            }

            engineControls
        }
    }

    /// Engine choice, plus the model field the AI engine needs. Shown inline
    /// because this is where a learner discovers they need it — after Apple
    /// Speech has failed on their language.
    @ViewBuilder
    private var engineControls: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Transcription Engine", systemImage: "waveform.and.person.filled")
                    .font(.subheadline)
                Text(engineFootnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Picker("Transcription Engine", selection: engineBinding) {
                ForEach(AudioTranscriptionEngine.allCases) { engine in
                    Text(localizedTitle(for: engine)).tag(engine)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(isBusy || captureService.isRecording)
        }

        if aiSettings.transcriptionEngine == .aiProvider {
            if let provider = aiSettings.transcriptionProvider() {
                HStack(spacing: 10) {
                    Label {
                        Text("Model")
                            .font(.caption)
                    } icon: {
                        ProviderIcon(provider: provider, size: 14)
                    }
                    TextField(
                        provider.defaultTranscriptionModels.first
                            ?? String(localized: "speech-to-text model id", bundle: .appLanguage),
                        text: transcriptionModelBinding(for: provider)
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                    .disabled(isBusy || captureService.isRecording)
                }

                // Naming the account the audio goes to is the point: this is a
                // decision about where a recording is uploaded, so it must not
                // be inferable only from a small icon.
                Text("Audio is sent to \(provider.displayName).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !provider.supportsAudioTranscription {
                    Label(
                        "OpenAI, Qwen, and Quotio are the providers documented to transcribe audio. \(provider.displayName) is your selected provider, so it is asked too — enter its speech-to-text model id below. If it does not offer one, it will say so and you can switch providers or use Apple Speech.",
                        systemImage: "info.circle"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Label(
                    "AI transcription needs a cloud provider. Add an API key in Settings → AI, or switch back to Apple Speech.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption2)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var engineBinding: Binding<AudioTranscriptionEngine> {
        Binding(
            get: { aiSettings.transcriptionEngine },
            set: { aiSettings.transcriptionEngine = $0 }
        )
    }

    private func transcriptionModelBinding(for provider: AIProvider) -> Binding<String> {
        Binding(
            get: { aiSettings.transcriptionModel(for: provider) },
            set: { aiSettings.setTranscriptionModel($0, for: provider) }
        )
    }

    private var engineFootnote: LocalizedStringKey {
        switch aiSettings.transcriptionEngine {
        case .appleSpeech:
            return "On-device when the language is installed; free."
        case .aiProvider:
            return "Sends the audio to your AI provider; usually billed."
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                begin(.transcribeToEditor)
            } label: {
                Label("Transcribe to Editor", systemImage: "text.cursor")
                    .fitSingleLine(0.68)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                begin(.translateAudio)
            } label: {
                Label("Translate Audio", systemImage: "translate")
                    .fitSingleLine(0.68)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .disabled(selectedAudio == nil || captureService.isRecording || isPreparingFile)
    }

    private func operationProgress(_ operation: AudioInputOperation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(operation.progressTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Cancel", role: .cancel) {
                    cancelOperation()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // The first transcription in a language downloads its on-device
            // model, which can take a while. Without this the pane looks hung
            // on exactly the run that is doing the most work.
            if let progress = transcriptionService.modelDownloadProgress {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Downloading the \(recognitionLanguage.displayName) speech model…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: min(max(progress, 0), 1))
                        .accessibilityLabel("Speech model download")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func toggleRecording() {
        errorMessage = nil
        statusMessage = nil

        if captureService.isRecording {
            cancelRecordingLimit()
            do {
                let recordedURL = try captureService.stopRecording()
                prepareRecording(at: recordedURL)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            cancelPreparation()
            let requestID = UUID()
            preparationID = requestID
            preparationTask = Task {
                do {
                    try await captureService.startRecording()
                    try Task.checkCancellation()
                    guard preparationID == requestID else {
                        captureService.discardActiveRecording()
                        return
                    }
                    scheduleRecordingLimit()
                } catch is CancellationError {
                    // Leaving the pane while a permission prompt is open must
                    // not start a hidden recording after the prompt resolves.
                } catch {
                    if preparationID == requestID {
                        errorMessage = error.localizedDescription
                    }
                }
                finishPreparation(requestID)
            }
        }
    }

    private func prepareRecording(at url: URL) {
        cancelPreparation()
        let requestID = UUID()
        preparationID = requestID
        isPreparingFile = true
        preparationTask = Task {
            do {
                let prepared = try await AudioInputFileStore.prepareRecording(at: url)
                guard !Task.isCancelled, preparationID == requestID else {
                    AudioInputFileStore.remove(prepared.url)
                    return
                }
                replaceSelection(with: prepared)
                statusMessage = String(localized: "Recording ready for transcription.", bundle: .appLanguage)
                statusKind = .success
            } catch is CancellationError {
                AudioInputFileStore.remove(url)
            } catch {
                if preparationID == requestID {
                    errorMessage = error.localizedDescription
                }
            }
            finishPreparation(requestID)
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let sourceURL = urls.first else {
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
            return
        }

        errorMessage = nil
        statusMessage = nil
        cancelPreparation()
        let requestID = UUID()
        preparationID = requestID
        isPreparingFile = true
        preparationTask = Task {
            do {
                let prepared = try await AudioInputFileStore.importAudio(from: sourceURL)
                guard !Task.isCancelled, preparationID == requestID else {
                    AudioInputFileStore.remove(prepared.url)
                    return
                }
                replaceSelection(with: prepared)
                statusMessage = String(localized: "Audio file ready for transcription.", bundle: .appLanguage)
                statusKind = .success
            } catch is CancellationError {
                // Picker dismissal or replacement is not an error.
            } catch {
                if preparationID == requestID {
                    errorMessage = error.localizedDescription
                }
            }
            finishPreparation(requestID)
        }
    }

    private func cancelPreparation() {
        preparationTask?.cancel()
        preparationTask = nil
        preparationID = nil
        isPreparingFile = false
    }

    private func finishPreparation(_ requestID: UUID) {
        guard preparationID == requestID else { return }
        preparationTask = nil
        preparationID = nil
        isPreparingFile = false
    }

    private func replaceSelection(with audio: PreparedAudioFile) {
        captureService.stopPlayback()
        if let previous = selectedAudio, previous.url != audio.url {
            AudioInputFileStore.remove(previous.url)
        }
        selectedAudio = audio
    }

    private func removeSelectedAudio() {
        cancelOperation()
        captureService.stopPlayback()
        if let selectedAudio {
            AudioInputFileStore.remove(selectedAudio.url)
        }
        selectedAudio = nil
        statusMessage = nil
        errorMessage = nil
    }

    private func begin(_ action: MultimodalAudioAction) {
        guard let selectedAudio else { return }

        cancelOperation(showStatus: false)
        captureService.stopPlayback()
        errorMessage = nil
        statusMessage = nil
        offerAIFallback = false
        operation = action == .transcribeToEditor ? .transcribing : .translating
        let requestID = UUID()
        operationID = requestID
        let engine = aiSettings.transcriptionEngine

        operationTask = Task {
            do {
                let transcript = try await transcriptionService.transcribe(
                    audioURL: selectedAudio.url,
                    language: recognitionLanguage,
                    engine: engine
                )
                try Task.checkCancellation()
                guard operationID == requestID else { return }
                try await onResult(transcript, recognitionLanguage, action)
                try Task.checkCancellation()
                guard operationID == requestID else { return }
                statusMessage = action == .transcribeToEditor
                    ? String(localized: "Transcript added to the editor.", bundle: .appLanguage)
                    : String(localized: "Translation complete.", bundle: .appLanguage)
                statusKind = .success
            } catch is CancellationError {
                if operationID == requestID {
                    statusMessage = String(localized: "Cancelled.", bundle: .appLanguage)
                    statusKind = .neutral
                }
            } catch {
                if operationID == requestID {
                    errorMessage = error.localizedDescription
                    // Apple Speech has no model for this language on a lot of
                    // devices. Offer the switch rather than leaving a dead end.
                    offerAIFallback = engine == .appleSpeech
                        && aiSettings.isAITranscriptionAvailable
                }
            }
            if operationID == requestID {
                operation = nil
                operationTask = nil
                operationID = nil
            }
        }
    }

    /// Switch to the AI engine and retry the same action.
    private func retryWithAI(_ action: MultimodalAudioAction) {
        aiSettings.transcriptionEngine = .aiProvider
        offerAIFallback = false
        begin(action)
    }

    private func cancelOperation(showStatus: Bool = true) {
        operationTask?.cancel()
        transcriptionService.cancel()
        operationTask = nil
        operationID = nil
        operation = nil
        if showStatus {
            statusMessage = String(localized: "Cancelled.", bundle: .appLanguage)
            statusKind = .neutral
        }
    }

    private func scheduleRecordingLimit() {
        cancelRecordingLimit()
        let requestID = UUID()
        recordingLimitID = requestID
        recordingLimitTask = Task {
            do {
                try await Task.sleep(for: .seconds(AudioInputFileStore.maximumDurationSeconds))
                try Task.checkCancellation()
                guard recordingLimitID == requestID, captureService.isRecording else { return }
                let recordedURL = try captureService.stopRecording()
                if recordingLimitID == requestID {
                    recordingLimitTask = nil
                    recordingLimitID = nil
                }
                prepareRecording(at: recordedURL)
            } catch is CancellationError {
                // Manual stop or leaving the pane cancels the deadline.
            } catch {
                if recordingLimitID == requestID {
                    errorMessage = error.localizedDescription
                }
            }
            if recordingLimitID == requestID {
                recordingLimitTask = nil
                recordingLimitID = nil
            }
        }
    }

    private func cancelRecordingLimit() {
        recordingLimitTask?.cancel()
        recordingLimitTask = nil
        recordingLimitID = nil
    }

    private var statusSymbol: String {
        switch statusKind {
        case .success: return "checkmark.circle.fill"
        case .neutral: return "xmark.circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        }
    }

    private var statusColor: Color {
        switch statusKind {
        case .success: return .green
        case .neutral: return .secondary
        case .inProgress: return .blue
        }
    }

    private func metadataDescription(for audio: PreparedAudioFile) -> String {
        var components = [ByteCountFormatter.string(fromByteCount: audio.byteCount, countStyle: .file)]
        if let duration = audio.duration {
            components.insert(formatDuration(duration), at: 0)
        }
        components.append(
            audio.source == .recording
                ? String(localized: "Recording", bundle: .appLanguage)
                : String(localized: "Imported file", bundle: .appLanguage)
        )
        return components.joined(separator: " · ")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func localizedTitle(for language: SpeechRecognitionLanguage) -> LocalizedStringKey {
        switch language {
        case .english: return "English"
        case .chinese: return "Chinese (Simplified)"
        case .chineseTraditional: return "Chinese (Traditional)"
        }
    }

    private func localizedTitle(for engine: AudioTranscriptionEngine) -> LocalizedStringKey {
        switch engine {
        case .appleSpeech: return "Apple Speech"
        case .aiProvider: return "AI Provider"
        }
    }
}
