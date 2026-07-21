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
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(String(localized: "Audio error:") + " " + errorMessage)
            } else if let statusMessage {
                Label(statusMessage, systemImage: statusSymbol)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(
                "Transcription uses Apple Speech and prefers on-device recognition when available. When on-device recognition is unavailable, Apple may process the audio using its speech service. Your selected audio is not sent to MiniMax; Translate Audio may send the transcript to your configured translation provider.",
                systemImage: "hand.raised.fill"
            )
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
            statusMessage = String(localized: "Recording stopped because read-aloud started. Your clip is being prepared.")
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
                statusMessage = String(localized: "Recording ready for transcription.")
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
                statusMessage = String(localized: "Audio file ready for transcription.")
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
        operation = action == .transcribeToEditor ? .transcribing : .translating
        let requestID = UUID()
        operationID = requestID

        operationTask = Task {
            do {
                let transcript = try await transcriptionService.transcribe(
                    audioURL: selectedAudio.url,
                    language: recognitionLanguage
                )
                try Task.checkCancellation()
                guard operationID == requestID else { return }
                try await onResult(transcript, recognitionLanguage, action)
                try Task.checkCancellation()
                guard operationID == requestID else { return }
                statusMessage = action == .transcribeToEditor
                    ? String(localized: "Transcript added to the editor.")
                    : String(localized: "Translation complete.")
                statusKind = .success
            } catch is CancellationError {
                if operationID == requestID {
                    statusMessage = String(localized: "Cancelled.")
                    statusKind = .neutral
                }
            } catch {
                if operationID == requestID {
                    errorMessage = error.localizedDescription
                }
            }
            if operationID == requestID {
                operation = nil
                operationTask = nil
                operationID = nil
            }
        }
    }

    private func cancelOperation(showStatus: Bool = true) {
        operationTask?.cancel()
        transcriptionService.cancel()
        operationTask = nil
        operationID = nil
        operation = nil
        if showStatus {
            statusMessage = String(localized: "Cancelled.")
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
                ? String(localized: "Recording")
                : String(localized: "Imported file")
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
}
