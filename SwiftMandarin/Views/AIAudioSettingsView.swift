//
//  AIAudioSettingsView.swift
//  SwiftMandarin
//
//  Cross-platform MiniMax AI Audio settings and generated-audio library.
//

import SwiftUI
import UniformTypeIdentifiers

private enum MiniMaxVoiceSelectionSlot: String, Identifiable {
    case mandarin
    case english

    var id: String { rawValue }
}

struct AIAudioSettingsView: View {
    @State private var preferences = AppPreferences.shared
    @State private var aiSettings = AIModelSettings.shared
    @State private var runtime = AIAudioRuntimeState.shared
    @State private var generatedAudio = GeneratedSpeechStore.shared
    @State private var catalogStore = MiniMaxAudioCatalogStore.shared

    @State private var miniMaxAPIKey = ""
    @State private var showingLibrary = false
    @State private var confirmingClear = false
    @State private var errorMessage: String?
    @State private var showingAdvancedVoiceIDs = false
    @State private var previewTask: Task<Void, Never>?
    @State private var previewMessage: String?
    @State private var previewIsError = false
    @State private var selectedVoiceSlot: MiniMaxVoiceSelectionSlot?

    var body: some View {
        Form {
            Section {
                Toggle("Use MiniMax AI Audio", isOn: $preferences.aiAudioEnabled)

                if preferences.aiAudioEnabled && !hasMiniMaxKey {
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
                Button {
                    refreshCatalog()
                } label: {
                    HStack {
                        Label("Refresh MiniMax Catalog", systemImage: "arrow.clockwise")
                        Spacer()
                        if catalogStore.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Refreshing MiniMax voices")
                        }
                    }
                }
                .disabled(!hasMiniMaxKey || catalogStore.isRefreshing)

                if let catalog = catalogStore.catalog {
                    LabeledContent("Voice Catalog") {
                        Text(catalogStatus(catalog))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Available Voices") {
                        Text("\(catalog.mandarinSystemVoices.count) Mandarin · \(catalog.englishSystemVoices.count) English")
                            .foregroundStyle(.secondary)
                    }
                } else if !hasMiniMaxKey {
                    Label("Add a MiniMax API key to load the latest voices.", systemImage: "key.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let message = catalogStore.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if let message = catalogStore.warningMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Speech Catalog")
            } footer: {
                Text("Speech models come from MiniMax's current T2A documentation because its general model endpoint does not list speech models. Voices refresh live from the selected regional account; the last public system-voice catalog remains available offline.")
            }

            Section {
                Picker("Speech Model", selection: $preferences.aiAudioModel) {
                    if MiniMaxSpeechModelDescriptor.descriptor(for: preferences.aiAudioModel) == nil {
                        Text("Current Selection · \(preferences.aiAudioModel)")
                            .tag(preferences.aiAudioModel)
                    }
                    Section("Latest") {
                        ForEach(latestSpeechModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    Section("Older Compatible Models") {
                        ForEach(legacySpeechModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                }

                voiceSelectionButton(
                    title: "Mandarin Voice",
                    voiceID: preferences.aiAudioChineseVoice
                ) {
                    selectedVoiceSlot = .mandarin
                }

                if chineseVoiceMismatch {
                    Label("The selected Mandarin slot contains a known English system voice. Choose a Mandarin or account voice before previewing.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                voiceSelectionButton(
                    title: "English Voice",
                    voiceID: preferences.aiAudioEnglishVoice
                ) {
                    selectedVoiceSlot = .english
                }

                if englishVoiceMismatch {
                    Label("The selected English slot contains a known Mandarin system voice. Choose an English or account voice before previewing.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                DisclosureGroup("Advanced Voice IDs", isExpanded: $showingAdvancedVoiceIDs) {
                    TextField(
                        "Mandarin Voice ID",
                        text: customVoiceBinding(for: .mandarin)
                    )
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif

                    TextField(
                        "English Voice ID",
                        text: customVoiceBinding(for: .english)
                    )
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif

                    Text("Account-created voices normally have no language metadata. Recognized Chinese/English system prefixes are validated; other IDs are assigned by the language slot where you place them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ViewThatFits(in: .horizontal) {
                    HStack {
                        Link(destination: voiceLibraryURL) {
                            Label("Browse Voice IDs", systemImage: "arrow.up.right.square")
                        }
                        Spacer()
                        restoreVoiceDefaultsButton
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Link(destination: voiceLibraryURL) {
                            Label("Browse Voice IDs", systemImage: "arrow.up.right.square")
                        }
                        restoreVoiceDefaultsButton
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
                Text("MiniMax generates mono MP3 audio at 32 kHz and 128 kbps. Normal read-aloud can use system speech on failure; the preview below never falls back, so it tests the selected MiniMax region, model, and voice honestly.")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        preview(
                            text: "你好，很高兴认识你。我们一起练习普通话吧。",
                            languageCode: "zh-CN",
                            voice: preferences.aiAudioChineseVoice
                        )
                    } label: {
                        Label("Preview Mandarin with MiniMax", systemImage: "waveform.badge.magnifyingglass")
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    }
                    .disabled(runtime.isBusy || !hasMiniMaxKey || chineseVoiceMismatch)

                    Button {
                        preview(
                            text: "Hello. It’s great to meet you. Let’s practice English together.",
                            languageCode: "en-US",
                            voice: preferences.aiAudioEnglishVoice
                        )
                    } label: {
                        Label("Preview English with MiniMax", systemImage: "waveform.badge.magnifyingglass")
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    }
                    .disabled(runtime.isBusy || !hasMiniMaxKey || englishVoiceMismatch)

                    if runtime.isBusy {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Generating MiniMax preview")
                            Text("Testing MiniMax…")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Cancel Preview") {
                                previewTask?.cancel()
                                previewTask = nil
                                previewMessage = nil
                                previewIsError = false
                                SpeechService.stop()
                            }
                        }
                    }
                }

                if let previewMessage {
                    Label(
                        previewMessage,
                        systemImage: previewIsError
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(previewIsError ? .red : .green)
                } else if let message = runtime.message {
                    Label(message, systemImage: statusSymbol)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                } else {
                    Text("Each preview makes or reuses one MiniMax clip. It never substitutes a system voice, and new generation may incur charges.")
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
        .task(id: preferences.aiAudioRegion) {
            miniMaxAPIKey = aiSettings.apiKey(for: .minimax)
            await generatedAudio.refresh()
            catalogStore.activate(region: preferences.aiAudioRegion)
            catalogStore.activateCredential(
                region: preferences.aiAudioRegion,
                apiKey: miniMaxAPIKey
            )
            await catalogStore.loadCachedCatalog(for: preferences.aiAudioRegion)
            if hasMiniMaxKey {
                await catalogStore.refresh(
                    region: preferences.aiAudioRegion,
                    apiKey: miniMaxAPIKey
                )
                reconcileSelectedVoiceProvenance()
            }
        }
        .onDisappear {
            previewTask?.cancel()
            previewTask = nil
            catalogStore.cancelRefresh()
        }
        .sheet(isPresented: $showingLibrary) {
            GeneratedAudioLibraryView()
                .localizedSurface()
        }
        .sheet(item: $selectedVoiceSlot) { slot in
            MiniMaxVoiceSelectionView(
                title: slot == .mandarin ? "Mandarin Voice" : "English Voice",
                voices: slot == .mandarin ? mandarinVoiceOptions : englishVoiceOptions,
                selection: slot == .mandarin
                    ? preferences.aiAudioChineseVoice
                    : preferences.aiAudioEnglishVoice,
                onSelect: { voice in selectVoice(voice, for: slot) },
                onUseCurrentCustomID: { markVoiceAsCustom(for: slot) }
            )
            .localizedSurface()
        }
        .alert("Clear Saved Audio?", isPresented: $confirmingClear) {
            Button("Clear All", role: .destructive) {
                SpeechService.stop()
                BatchExplanationController.shared.cancel()
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

    private var latestSpeechModels: [MiniMaxSpeechModelDescriptor] {
        catalogStore.speechModels.filter(\.isLatestFamily)
    }

    private var legacySpeechModels: [MiniMaxSpeechModelDescriptor] {
        catalogStore.speechModels.filter { $0.lifecycle == .legacy }
    }

    private var mandarinVoiceOptions: [MiniMaxVoiceDescriptor] {
        uniqueVoices(
            (catalogStore.catalog?.mandarinSystemVoices ?? [])
                + (catalogStore.catalog?.accountVoices ?? [])
        )
    }

    private var englishVoiceOptions: [MiniMaxVoiceDescriptor] {
        uniqueVoices(
            (catalogStore.catalog?.englishSystemVoices ?? [])
                + (catalogStore.catalog?.accountVoices ?? [])
        )
    }

    private var chineseVoiceMismatch: Bool {
        !preferences.aiAudioChineseVoiceUsesCustomLanguage
            && knownLanguage(for: preferences.aiAudioChineseVoice) == .english
    }

    private var englishVoiceMismatch: Bool {
        !preferences.aiAudioEnglishVoiceUsesCustomLanguage
            && knownLanguage(for: preferences.aiAudioEnglishVoice) == .mandarinChinese
    }

    private func uniqueVoices(_ voices: [MiniMaxVoiceDescriptor]) -> [MiniMaxVoiceDescriptor] {
        var seen = Set<String>()
        return voices
            .filter { seen.insert($0.voiceID).inserted }
            .sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
    }

    private func knownLanguage(for voiceID: String) -> MiniMaxKnownVoiceLanguage? {
        catalogStore.knownLanguage(
            for: voiceID,
            region: preferences.aiAudioRegion
        )
    }

    private func voiceSelectionButton(
        title: LocalizedStringKey,
        voiceID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            LabeledContent {
                HStack(spacing: 6) {
                    Text(selectedVoiceName(for: voiceID))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            } label: {
                Text(title)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens a searchable MiniMax voice list")
    }

    private func selectedVoiceName(for voiceID: String) -> String {
        let voices = (catalogStore.catalog?.systemVoices ?? [])
            + (catalogStore.catalog?.accountVoices ?? [])
        return voices.first { $0.voiceID == voiceID }?.displayName ?? voiceID
    }

    private func catalogStatus(_ catalog: MiniMaxVoiceCatalog) -> String {
        let source = catalog.origin == .live
            ? String(localized: "Live")
            : String(localized: "Saved Offline")
        return source + " · " + catalog.fetchedAt.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    private func refreshCatalog() {
        guard hasMiniMaxKey else { return }
        Task {
            await catalogStore.refresh(
                region: preferences.aiAudioRegion,
                apiKey: miniMaxAPIKey
            )
            reconcileSelectedVoiceProvenance()
        }
    }

    private func preview(text: String, languageCode: String, voice: String) {
        previewTask?.cancel()
        SpeechService.stop()
        previewMessage = nil
        previewIsError = false

        let model = preferences.aiAudioModel
        let voiceName = selectedVoiceName(for: voice)
        let modelName = MiniMaxSpeechModelDescriptor.descriptor(for: model)?.displayName ?? model
        previewTask = Task { @MainActor in
            do {
                try await SpeechService.previewMiniMaxAndWait(
                    text,
                    languageCode: languageCode
                )
                try Task.checkCancellation()
                previewMessage = String(localized: "Played with MiniMax")
                    + " · \(voiceName) · \(modelName)"
                previewIsError = false
            } catch is CancellationError {
                // Cancel is already represented by returning to the idle state.
            } catch {
                previewMessage = error.localizedDescription
                previewIsError = true
            }
            previewTask = nil
        }
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { miniMaxAPIKey },
            set: { value in
                guard value != miniMaxAPIKey else { return }
                miniMaxAPIKey = value
                aiSettings.setAPIKey(value, for: .minimax)
            }
        )
    }

    private var hasMiniMaxKey: Bool {
        !miniMaxAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var restoreVoiceDefaultsButton: some View {
        Button("Restore Defaults") {
            preferences.aiAudioModel = MiniMaxSpeechConfiguration.defaultModel
            preferences.aiAudioChineseVoice = MiniMaxSpeechConfiguration.defaultChineseVoice
            preferences.aiAudioEnglishVoice = MiniMaxSpeechConfiguration.defaultEnglishVoice
            preferences.aiAudioChineseVoiceUsesCustomLanguage = false
            preferences.aiAudioEnglishVoiceUsesCustomLanguage = false
        }
    }

    private func customVoiceBinding(for slot: MiniMaxVoiceSelectionSlot) -> Binding<String> {
        Binding(
            get: {
                slot == .mandarin
                    ? preferences.aiAudioChineseVoice
                    : preferences.aiAudioEnglishVoice
            },
            set: { value in
                let usesCustomAssignment = usesSlotLanguageAssignment(for: value)
                if slot == .mandarin {
                    preferences.aiAudioChineseVoice = value
                    preferences.aiAudioChineseVoiceUsesCustomLanguage = usesCustomAssignment
                } else {
                    preferences.aiAudioEnglishVoice = value
                    preferences.aiAudioEnglishVoiceUsesCustomLanguage = usesCustomAssignment
                }
            }
        )
    }

    private func selectVoice(
        _ voice: MiniMaxVoiceDescriptor,
        for slot: MiniMaxVoiceSelectionSlot
    ) {
        let usesCustomAssignment = voice.source != .system
        if slot == .mandarin {
            preferences.aiAudioChineseVoice = voice.voiceID
            preferences.aiAudioChineseVoiceUsesCustomLanguage = usesCustomAssignment
        } else {
            preferences.aiAudioEnglishVoice = voice.voiceID
            preferences.aiAudioEnglishVoiceUsesCustomLanguage = usesCustomAssignment
        }
    }

    private func markVoiceAsCustom(for slot: MiniMaxVoiceSelectionSlot) {
        if slot == .mandarin {
            // Preserve provenance learned from an earlier live catalog across
            // relaunches. Otherwise apply the same prefix validation used by
            // manual edits so this action cannot waive a known mismatch.
            guard !preferences.aiAudioChineseVoiceUsesCustomLanguage else { return }
            preferences.aiAudioChineseVoiceUsesCustomLanguage = usesSlotLanguageAssignment(
                for: preferences.aiAudioChineseVoice
            )
        } else {
            guard !preferences.aiAudioEnglishVoiceUsesCustomLanguage else { return }
            preferences.aiAudioEnglishVoiceUsesCustomLanguage = usesSlotLanguageAssignment(
                for: preferences.aiAudioEnglishVoice
            )
        }
    }

    private func usesSlotLanguageAssignment(for voiceID: String) -> Bool {
        let catalogVoice = ((catalogStore.catalog?.systemVoices ?? [])
            + (catalogStore.catalog?.accountVoices ?? []))
            .first { $0.voiceID == voiceID }
        return MiniMaxVoiceDescriptor.usesSlotLanguageAssignment(
            voiceID: voiceID,
            catalogSource: catalogVoice?.source
        )
    }

    private func reconcileSelectedVoiceProvenance() {
        guard let catalog = catalogStore.catalog, catalog.origin == .live else { return }
        // Prefer explicit account provenance if an API response ever contains
        // a duplicate ID; avoid constructing a unique-key dictionary from
        // server-owned data.
        let liveVoices = catalog.accountVoices + catalog.systemVoices

        if let chineseVoice = liveVoices.first(where: {
            $0.voiceID == preferences.aiAudioChineseVoice
        }) {
            preferences.aiAudioChineseVoiceUsesCustomLanguage =
                MiniMaxVoiceDescriptor.reconciledSlotLanguageAssignment(
                    voiceID: chineseVoice.voiceID,
                    persistedAssignment: preferences.aiAudioChineseVoiceUsesCustomLanguage,
                    liveCatalogSource: chineseVoice.source,
                    scopeChanged: false
                )
        }
        if let englishVoice = liveVoices.first(where: {
            $0.voiceID == preferences.aiAudioEnglishVoice
        }) {
            preferences.aiAudioEnglishVoiceUsesCustomLanguage =
                MiniMaxVoiceDescriptor.reconciledSlotLanguageAssignment(
                    voiceID: englishVoice.voiceID,
                    persistedAssignment: preferences.aiAudioEnglishVoiceUsesCustomLanguage,
                    liveCatalogSource: englishVoice.source,
                    scopeChanged: false
                )
        }
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

private struct MiniMaxVoiceSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let title: LocalizedStringKey
    let voices: [MiniMaxVoiceDescriptor]
    let selection: String
    let onSelect: (MiniMaxVoiceDescriptor) -> Void
    let onUseCurrentCustomID: () -> Void

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                if !voices.contains(where: { $0.voiceID == selection }) {
                    Section("Current / Custom") {
                        Button {
                            onUseCurrentCustomID()
                            dismiss()
                        } label: {
                            voiceLabel(
                                name: selection,
                                voiceID: selection,
                                description: String(localized: "This voice is not in the current live catalog."),
                                isSelected: true
                            )
                        }
                    }
                }

                voiceSection(
                    "System Voices",
                    voices: filteredVoices.filter { $0.source == .system }
                )
                voiceSection(
                    "Your Voices",
                    voices: filteredVoices.filter { $0.source != .system }
                )

                if filteredVoices.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search voices")
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 520)
        #endif
    }

    private var filteredVoices: [MiniMaxVoiceDescriptor] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return voices }
        return voices.filter { voice in
            voice.displayName.localizedCaseInsensitiveContains(query)
                || voice.voiceID.localizedCaseInsensitiveContains(query)
                || voice.descriptions.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
        }
    }

    @ViewBuilder
    private func voiceSection(
        _ title: LocalizedStringKey,
        voices: [MiniMaxVoiceDescriptor]
    ) -> some View {
        if !voices.isEmpty {
            Section(title) {
                ForEach(voices) { voice in
                    Button {
                        onSelect(voice)
                        dismiss()
                    } label: {
                        voiceLabel(
                            name: voice.displayName,
                            voiceID: voice.voiceID,
                            description: voice.descriptions.first,
                            isSelected: selection == voice.voiceID
                        )
                    }
                }
            }
        }
    }

    private func voiceLabel(
        name: String,
        voiceID: String,
        description: String?,
        isSelected: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .foregroundStyle(.primary)
                if name != voiceID {
                    Text(voiceID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if let description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
                BatchExplanationController.shared.cancel()
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

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    playbackButton(record)
                    shareButton(record)
                    exportButton(record)
                    Spacer()
                    deleteButton(record)
                }

                VStack(alignment: .leading, spacing: 8) {
                    playbackButton(record)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    shareButton(record)
                    exportButton(record)
                    Button(role: .destructive) {
                        delete(record)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
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

    private func playbackButton(_ record: GeneratedSpeechRecord) -> some View {
        Button {
            if isPlaying(record) {
                SpeechService.stop()
            } else {
                Task {
                    do {
                        try await SpeechService.playGeneratedAudio(recordID: record.id)
                    } catch is CancellationError {
                        // Starting another read-aloud action normally supersedes
                        // this row; that is not a user error.
                    } catch MiniMaxAudioError.cancelled {
                        // The request was intentionally replaced or stopped.
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } label: {
            Label(
                isPlaying(record) ? "Stop" : "Play",
                systemImage: isPlaying(record) ? "stop.fill" : "play.fill"
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    @ViewBuilder
    private func shareButton(_ record: GeneratedSpeechRecord) -> some View {
        if let url = fileURLs[record.id] {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func exportButton(_ record: GeneratedSpeechRecord) -> some View {
        Button {
            prepareExport(record)
        } label: {
            Label("Export…", systemImage: "folder.badge.plus")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func deleteButton(_ record: GeneratedSpeechRecord) -> some View {
        Button(role: .destructive) {
            delete(record)
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text("Delete saved audio"))
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
        BatchExplanationController.shared.cancel()
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
