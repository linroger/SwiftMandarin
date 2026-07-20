//
//  AIAudioSettingsView.swift
//  SwiftMandarin
//
//  Cross-platform MiniMax AI Audio settings and generated-audio library.
//

import SwiftUI
import UniformTypeIdentifiers

struct AIAudioSettingsView: View {
    @State private var preferences = AppPreferences.shared
    @State private var aiSettings = AIModelSettings.shared
    @State private var runtime = AIAudioRuntimeState.shared
    @State private var generatedAudio = GeneratedSpeechStore.shared

    @State private var miniMaxAPIKey = ""
    @State private var showingLibrary = false
    @State private var confirmingClear = false
    @State private var errorMessage: String?

    private let speechModels = [
        "speech-2.8-turbo",
        "speech-2.8-hd",
        "speech-2.6-turbo",
        "speech-2.6-hd",
        "speech-02-turbo",
        "speech-02-hd",
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Use MiniMax AI Audio", isOn: $preferences.aiAudioEnabled)

                if preferences.aiAudioEnabled && miniMaxAPIKey.isEmpty {
                    Label("Add a MiniMax API key before using AI Audio.", systemImage: "key.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("AI Audio")
            } footer: {
                Text("Read-aloud text is sent to MiniMax only when a matching clip is not already saved. Generated MP3s stay on this device and are reused; MiniMax API usage may incur charges.")
            }

            Section {
                SecureField("MiniMax API Key", text: apiKeyBinding)
                    .textContentType(.password)

                if let keyURL = apiKeyURL {
                    Link(destination: keyURL) {
                        Label(apiKeyLinkTitle, systemImage: "arrow.up.right.square")
                    }
                }

                Picker("API Region", selection: $preferences.aiAudioRegion) {
                    ForEach(MiniMaxAPIRegion.allCases) { region in
                        Text(region.displayName).tag(region)
                    }
                }
            } header: {
                Text("MiniMax Connection")
            } footer: {
                Text("The key is stored only in the system Keychain and is shared with the MiniMax text provider. Choose the region where your key was issued.")
            }

            Section {
                Picker("Speech Model", selection: $preferences.aiAudioModel) {
                    ForEach(speechModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }

                TextField("Mandarin Voice ID", text: $preferences.aiAudioChineseVoice)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif

                TextField("English Voice ID", text: $preferences.aiAudioEnglishVoice)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif

                HStack {
                    Link(destination: voiceLibraryURL) {
                        Label("Browse Voice IDs", systemImage: "arrow.up.right.square")
                    }
                    Spacer()
                    Button("Restore Default Voices") {
                        preferences.aiAudioChineseVoice = MiniMaxSpeechConfiguration.defaultChineseVoice
                        preferences.aiAudioEnglishVoice = MiniMaxSpeechConfiguration.defaultEnglishVoice
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Voice Speed")
                        Spacer()
                        Text(verbatim: String(format: "%.2f×", preferences.aiAudioSpeed))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $preferences.aiAudioSpeed,
                        in: AppPreferences.aiAudioSpeedRange,
                        step: 0.05
                    ) {
                        Text("Voice Speed")
                    } minimumValueLabel: {
                        Text("0.5×")
                            .font(.caption)
                    } maximumValueLabel: {
                        Text("2×")
                            .font(.caption)
                    }
                }

                Toggle(
                    "Use System Speech on Failure",
                    isOn: $preferences.aiAudioFallbackToSystemSpeech
                )
            } header: {
                Text("Voice")
            } footer: {
                Text("Voice IDs come from MiniMax's Voice Library. Keep the defaults unless you use a custom voice. MiniMax generates mono MP3 audio at 32 kHz and 128 kbps; system speech can take over when generation fails.")
            }

            Section {
                HStack(spacing: 10) {
                    Button {
                        SpeechService.speakChinese("你好，欢迎使用 MiniMax AI 语音。")
                    } label: {
                        Label("Preview Mandarin", systemImage: "waveform.badge.magnifyingglass")
                            .fitSingleLine(0.72)
                    }
                    .disabled(runtime.isBusy || !preferences.aiAudioEnabled || miniMaxAPIKey.isEmpty)

                    Button {
                        SpeechService.speakEnglish("Hello, welcome to MiniMax AI Audio.")
                    } label: {
                        Label("Preview English", systemImage: "waveform.badge.magnifyingglass")
                            .fitSingleLine(0.72)
                    }
                    .disabled(runtime.isBusy || !preferences.aiAudioEnabled || miniMaxAPIKey.isEmpty)

                    if runtime.isBusy {
                        ProgressView()
                            .controlSize(.small)
                        Button("Cancel") {
                            SpeechService.stop()
                        }
                    }
                }

                if let message = runtime.message {
                    Label(message, systemImage: statusSymbol)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                } else {
                    Text("Each preview uses a small amount of MiniMax API credit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Test AI Audio")
            }

            Section {
                LabeledContent("Saved Audio") {
                    Text("\(generatedAudio.records.count) · \(formattedBytes(generatedAudio.totalByteCount))")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showingLibrary = true
                } label: {
                    Label("Manage Saved Audio", systemImage: "music.note.list")
                }

                Button(role: .destructive) {
                    confirmingClear = true
                } label: {
                    Label("Clear Saved Audio", systemImage: "trash")
                }
                .disabled(
                    generatedAudio.records.isEmpty
                        && generatedAudio.lastErrorMessage == nil
                )

                if let libraryError = generatedAudio.lastErrorMessage {
                    Label(libraryError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Local Library")
            } footer: {
                Text("Generated MP3 files stay in SwiftMandarin until you delete them. Exported copies remain wherever you save or share them.")
            }
        }
        .navigationTitle("AI Audio")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #elseif os(macOS)
        .formStyle(.grouped)
        .padding()
        #endif
        .task {
            miniMaxAPIKey = aiSettings.apiKey(for: .minimax)
            await generatedAudio.refresh()
        }
        .sheet(isPresented: $showingLibrary) {
            GeneratedAudioLibraryView()
                .localizedSurface()
        }
        .alert("Clear Saved Audio?", isPresented: $confirmingClear) {
            Button("Clear All", role: .destructive) {
                SpeechService.stop()
                Task {
                    do {
                        try await generatedAudio.clearAll()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every locally generated MiniMax audio file. Audio you already exported is not affected.")
        }
        .alert("AI Audio Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "The AI Audio action could not be completed."))
        }
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { miniMaxAPIKey },
            set: { value in
                miniMaxAPIKey = value
                aiSettings.setAPIKey(value, for: .minimax)
            }
        )
    }

    private var apiKeyURL: URL? {
        let value = preferences.aiAudioRegion == .international
            ? "https://platform.minimax.io/user-center/basic-information/interface-key"
            : "https://platform.minimaxi.com/user-center/basic-information/interface-key"
        return URL(string: value)
    }

    private var apiKeyLinkTitle: LocalizedStringKey {
        preferences.aiAudioRegion == .international
            ? "Get an International MiniMax key"
            : "Get a Mainland China MiniMax key"
    }

    private let voiceLibraryURL = URL(
        string: "https://platform.minimax.io/docs/faq/system-voice-id"
    )!

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var statusSymbol: String {
        switch runtime.phase {
        case .failed: return "exclamationmark.triangle.fill"
        case .localFallback: return "speaker.wave.2.fill"
        case .generating: return "sparkles"
        case .cacheHit: return "bolt.fill"
        case .playing: return "speaker.wave.3.fill"
        case .idle: return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch runtime.phase {
        case .failed: return .red
        case .localFallback: return .orange
        case .generating, .cacheHit, .playing: return .accentColor
        case .idle: return .secondary
        }
    }
}

struct GeneratedAudioLibraryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var store = GeneratedSpeechStore.shared
    @State private var runtime = AIAudioRuntimeState.shared
    @State private var fileURLs: [String: URL] = [:]
    @State private var exportDocument: GeneratedAudioExportDocument?
    @State private var exportFileName = "SwiftMandarin-Audio"
    @State private var showingExporter = false
    @State private var confirmingClear = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.records.isEmpty {
                    ProgressView("Loading saved audio…")
                } else if let libraryError = store.lastErrorMessage, store.records.isEmpty {
                    ContentUnavailableView {
                        Label("Saved Audio Unavailable", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(libraryError)
                    } actions: {
                        Button("Clear All…", role: .destructive) {
                            confirmingClear = true
                        }
                    }
                } else if store.records.isEmpty {
                    ContentUnavailableView {
                        Label("No Saved Audio", systemImage: "waveform")
                    } description: {
                        Text("Enable AI Audio and use any read-aloud button. Generated clips will appear here for replay and export.")
                    }
                } else {
                    List {
                        Section {
                            ForEach(store.records) { record in
                                generatedAudioRow(record)
                            }
                        } header: {
                            Text("\(store.records.count) files · \(formattedBytes(store.totalByteCount))")
                        }
                    }
                }
            }
            .navigationTitle("Saved Audio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if !store.records.isEmpty || store.lastErrorMessage != nil {
                        Button(role: .destructive) {
                            confirmingClear = true
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 480)
        #endif
        .task {
            await store.refresh()
            await refreshFileURLs()
        }
        .task(id: store.records.map(\.id)) {
            await refreshFileURLs()
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .mp3,
            defaultFilename: exportFileName
        ) { result in
            if case let .failure(error) = result {
                errorMessage = error.localizedDescription
            }
            exportDocument = nil
        }
        .alert("Saved Audio Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "The saved-audio action could not be completed."))
        }
        .alert("Clear Saved Audio?", isPresented: $confirmingClear) {
            Button("Clear All", role: .destructive) {
                SpeechService.stop()
                Task {
                    do {
                        try await store.clearAll()
                        fileURLs.removeAll()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all locally generated MiniMax audio files.")
        }
    }

    private func generatedAudioRow(_ record: GeneratedSpeechRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(record.text)
                .font(.body)
                .lineLimit(3)
                .textSelection(.enabled)

            Text(metadata(for: record))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 10) {
                Button {
                    if isPlaying(record) {
                        SpeechService.stop()
                    } else {
                        Task {
                            do {
                                try await SpeechService.playGeneratedAudio(recordID: record.id)
                            } catch is CancellationError {
                                // Starting another read-aloud action normally
                                // supersedes this row; that is not a user error.
                            } catch MiniMaxAudioError.cancelled {
                                // The underlying request was intentionally
                                // replaced or stopped.
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    Label(
                        isPlaying(record) ? "Stop" : "Play",
                        systemImage: isPlaying(record)
                            ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if let url = fileURLs[record.id] {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    prepareExport(record)
                } label: {
                    Label("Export…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(role: .destructive) {
                    delete(record)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Delete saved audio"))
            }
        }
        .padding(.vertical, 6)
        .swipeActions {
            Button(role: .destructive) {
                delete(record)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func metadata(for record: GeneratedSpeechRecord) -> String {
        var parts = [
            record.createdAt.formatted(date: .abbreviated, time: .shortened),
            record.languageCode.uppercased(),
            record.model,
            record.voiceID,
        ]
        if let milliseconds = record.durationMilliseconds {
            parts.append(formattedDuration(milliseconds))
        }
        parts.append(formattedBytes(record.byteCount))
        return parts.joined(separator: " · ")
    }

    private func isPlaying(_ record: GeneratedSpeechRecord) -> Bool {
        guard runtime.currentRecordID == record.id else { return false }
        return runtime.phase == .playing || runtime.phase == .cacheHit
    }

    private func prepareExport(_ record: GeneratedSpeechRecord) {
        Task {
            do {
                let url = try await store.fileURL(for: record)
                let data = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: url)
                }.value
                guard !data.isEmpty else { throw MiniMaxAudioError.emptyAudio }
                exportDocument = GeneratedAudioExportDocument(data: data)
                exportFileName = "SwiftMandarin-\(record.languageCode)-\(record.cacheKey.prefix(8))"
                showingExporter = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func delete(_ record: GeneratedSpeechRecord) {
        if runtime.currentRecordID == record.id {
            SpeechService.stop()
        }
        Task {
            do {
                try await store.delete(record)
                fileURLs.removeValue(forKey: record.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshFileURLs() async {
        var refreshed: [String: URL] = [:]
        for record in store.records {
            if let url = try? await store.fileURL(for: record) {
                refreshed[record.id] = url
            }
        }
        fileURLs = refreshed
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

struct GeneratedAudioExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.mp3] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, !data.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private func formattedBytes(_ byteCount: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
}

private func formattedDuration(_ milliseconds: Int) -> String {
    let totalSeconds = max(0, milliseconds / 1_000)
    return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
}
