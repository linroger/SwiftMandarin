//
//  MoreView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//
//  The "More" tab: a compact hub that surfaces the most-used controls up top
//  and routes the rest of Settings into focused, single-purpose screens rather
//  than one long scrolling form. (Translation history lives in its own tab, so
//  it is intentionally not duplicated here.)
//

import SwiftUI
import Ollama

/// Destinations the More hub pushes onto its own navigation stack. On iOS these
/// are the former Learn/Phrases/Stats tabs, consolidated here to keep the tab
/// bar at five items.
enum MoreRoute: Hashable {
    case learn
    case phrases
    case stats
    case reader
    case practice
    case conversation
}

/// More tab — a streamlined learning, settings & about hub.
struct MoreView: View {
    @State private var localization = LocalizationManager.shared
    @State private var prefs = AppPreferences.shared
    @State private var aiSettings = AIModelSettings.shared
    @State private var path: [MoreRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                headerSection
                learningSection
                quickSetupSection
                settingsSection
                aboutSection
            }
            .navigationTitle("More")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .navigationDestination(for: MoreRoute.self) { route in
                switch route {
                case .learn: LearnView()
                case .phrases: PhrasesView()
                case .stats: StatsView()
                case .reader: ReaderView()
                case .practice: PracticeHubView()
                case .conversation: ConversationView()
                }
            }
        }
    }

    // MARK: - Sections

    private var learningSection: some View {
        Section {
            NavigationLink(value: MoreRoute.learn) {
                Label(AppTab.learn.titleKey, systemImage: AppTab.learn.icon)
            }
            NavigationLink(value: MoreRoute.practice) {
                Label(AppTab.practice.titleKey, systemImage: AppTab.practice.icon)
            }
            NavigationLink(value: MoreRoute.conversation) {
                Label(AppTab.conversation.titleKey, systemImage: AppTab.conversation.icon)
            }
            NavigationLink(value: MoreRoute.reader) {
                Label(AppTab.reader.titleKey, systemImage: AppTab.reader.icon)
            }
            NavigationLink(value: MoreRoute.phrases) {
                Label(AppTab.phrases.titleKey, systemImage: AppTab.phrases.icon)
            }
            NavigationLink(value: MoreRoute.stats) {
                Label(AppTab.stats.titleKey, systemImage: AppTab.stats.icon)
            }
        } header: {
            Text("Learning Tools")
        }
    }

    private var headerSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.tint)
                    .frame(width: 52, height: 52)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("SwiftMandarin")
                        .font(.headline)
                    Text(verbatim: "\(L("Version")) \(AppConfig.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var quickSetupSection: some View {
        Section {
            Picker("App Language", selection: $localization.language) {
                ForEach(AppLanguage.allCases) { language in
                    Label(language.displayName, systemImage: language.iconName).tag(language)
                }
            }

            Picker("I am a…", selection: $prefs.learnerMode) {
                ForEach(LearnerMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.iconName).tag(mode)
                }
            }
        } header: {
            Text("Quick Setup")
        }
    }

    private var settingsSection: some View {
        Section {
            NavigationLink {
                GeneralSettingsView()
            } label: {
                Label("General", systemImage: "gearshape")
            }

            NavigationLink {
                AISettingsDetailView()
            } label: {
                HStack {
                    Label("AI Provider", systemImage: "cpu")
                    Spacer()
                    Text(aiSettings.provider.displayName)
                        .foregroundStyle(.secondary)
                        .fitSingleLine(0.8)
                }
            }

            NavigationLink {
                AIAudioSettingsView()
            } label: {
                HStack {
                    Label("AI Audio", systemImage: "waveform")
                    Spacer()
                    Text(prefs.aiAudioEnabled ? "On" : "Off")
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink {
                BatchAIAnalysisView()
            } label: {
                HStack {
                    Label("Batch AI Analysis", systemImage: "sparkles.rectangle.stack")
                    Spacer()
                    // Live progress, visible even from the hub root, so the user
                    // knows a background run is still going after navigating back.
                    BatchAIAnalysisStatusBadge()
                }
            }

            NavigationLink {
                TranslationSettingsView()
            } label: {
                Label("Translation", systemImage: "character.bubble")
            }

            NavigationLink {
                DisplaySettingsView()
            } label: {
                Label("Display & Pinyin", systemImage: "textformat")
            }

            NavigationLink {
                DataManagementView()
            } label: {
                Label("Manage Data", systemImage: "externaldrive")
            }
        } header: {
            Text("Settings")
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink {
                AboutView()
            } label: {
                Label("About", systemImage: "info.circle")
            }

            Link(destination: AppConfig.privacyPolicyURL) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: AppConfig.reviewURL) {
                Label("Rate App", systemImage: "star")
            }

            ShareLink(item: AppConfig.appStoreURL) {
                Label("Share App", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("About & Support")
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @State private var prefs = AppPreferences.shared
    @State private var localization = LocalizationManager.shared

    var body: some View {
        Form {
            Section {
                Picker("App Language", selection: $localization.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Label(language.displayName, systemImage: language.iconName).tag(language)
                    }
                }
            } header: {
                Text("Language")
            } footer: {
                Text("Switch the entire app between the English and Mandarin versions.")
            }

            Section {
                Picker("I am a…", selection: $prefs.learnerMode) {
                    ForEach(LearnerMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.iconName).tag(mode)
                    }
                }
                Toggle("Dual-Language Narration", isOn: $prefs.dualNarration)
            } header: {
                Text("Learning Mode")
            } footer: {
                Text("\(prefs.learnerMode.detail) Dual narration speaks both the word and its translation aloud.")
            }
        }
        .navigationTitle("General")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Translation Settings

struct TranslationSettingsView: View {
    @AppStorage("defaultDirection") private var defaultDirection: String = TranslationDirection.englishToChinese.rawValue
    @AppStorage("autoTranslate") private var autoTranslate: Bool = false
    @AppStorage("translateOnPaste") private var translateOnPaste: Bool = true
    @AppStorage("autoSpeak") private var autoSpeak: Bool = false
    @AppStorage("copyTranslationAutomatically") private var copyTranslationAutomatically: Bool = false
    @AppStorage("saveToHistoryAutomatically") private var saveToHistoryAutomatically: Bool = true

    var body: some View {
        Form {
            Section {
                Picker("Default Direction", selection: $defaultDirection) {
                    ForEach(TranslationDirection.allCases) { direction in
                        Text(direction.label).tag(direction.rawValue)
                    }
                }

                Toggle("Auto-Translate While Typing", isOn: $autoTranslate)

                Text("When enabled, translation runs automatically as you type. When disabled, tap the Translate button after entering text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Translate on Paste", isOn: $translateOnPaste)

                Toggle("Auto-Speak Translations", isOn: $autoSpeak)
            } header: {
                Text("Translation")
            }

            Section {
                Toggle("Copy Translation Automatically", isOn: $copyTranslationAutomatically)
                Toggle("Save to History Automatically", isOn: $saveToHistoryAutomatically)
            } header: {
                Text("Output")
            }
        }
        .navigationTitle("Translation")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Display Settings

struct DisplaySettingsView: View {
    @AppStorage("showPinyin") private var showPinyin: Bool = true
    @AppStorage("pinyinPosition") private var pinyinPosition: String = "above"
    @AppStorage("toneColors") private var toneColors: Bool = true
    @AppStorage("vocabularyChineseFontSize") private var chineseFontSize: Double = 20
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true
    @State private var prefs = AppPreferences.shared

    /// Sample sentence for previewing the speech rate, in the learning language.
    private var speechSample: String {
        LocalizationManager.shared.learningIsChinese ? "你好，很高兴认识你。" : "Hello, nice to meet you."
    }

    var body: some View {
        Form {
            Section {
                Toggle("Show Pinyin", isOn: $showPinyin)

                Picker("Pinyin Position", selection: $pinyinPosition) {
                    Text("Above Characters").tag("above")
                    Text("Below Characters").tag("below")
                    Text("Inline").tag("inline")
                }
                .disabled(!showPinyin)

                Toggle("Tone Colors", isOn: $toneColors)
                    .disabled(!showPinyin)

                Text("Color-code pinyin based on tones (1st=red, 2nd=orange, 3rd=green, 4th=blue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading) {
                    HStack {
                        Text("Vocabulary Text Size")
                        Spacer()
                        Text(verbatim: "\(Int(chineseFontSize)) pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $chineseFontSize, in: 14...40, step: 2) {
                        Text("Vocabulary Text Size")
                    } minimumValueLabel: {
                        Text("A")
                            .font(.caption)
                    } maximumValueLabel: {
                        Text("A")
                            .font(.title3)
                    }
                }
            } header: {
                Text("Display")
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Speaking Speed")
                        Spacer()
                        Button {
                            SpeechService.speakAuto(speechSample)
                        } label: {
                            Label("Preview", systemImage: "speaker.wave.2.fill")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderless)
                    }
                    Slider(value: $prefs.ttsRate, in: AppPreferences.ttsRateRange) {
                        Text("Speaking Speed")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Image(systemName: "hare.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Applies to every read-aloud in the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Speech")
            }

            Section {
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            } header: {
                Text("Feedback")
            }
        }
        .navigationTitle("Display & Pinyin")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - AI Settings Detail View (iOS)

struct AISettingsDetailView: View {
    @State private var settings = AIModelSettings.shared
    @State private var ollamaService = OllamaService.shared

    var body: some View {
        Form {
            // Provider Selection
            Section {
                ForEach(AIProvider.allCases) { provider in
                    Button {
                        settings.provider = provider
                    } label: {
                        HStack {
                            ProviderIcon(provider: provider, size: 22)
                                .foregroundStyle(.tint)
                                .frame(width: 24)

                            VStack(alignment: .leading) {
                                Text(provider.displayName)
                                    .foregroundStyle(.primary)
                                    .fitSingleLine(0.8)
                                Text(provider.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if settings.provider == provider {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } header: {
                Text("AI Provider")
            }

            // Status
            Section {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(settings.statusMessage)
                        .font(.subheadline)
                }
            } header: {
                Text("Status")
            }

            // Provider-specific configuration (API key, model picker, etc.)
            AIProviderConfigView(settings: settings)

            // Photo AI cleanup (concern C)
            Section {
                Toggle("AI Photo Cleanup", isOn: $settings.aiPhotoCleanupEnabled)
            } header: {
                Text("Photo Recognition")
            } footer: {
                Text("When on, scanned photos are sent to the selected AI provider to fix OCR errors before translation. Vision-capable providers also receive the image.")
            }
        }
        .navigationTitle("AI Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await settings.refreshConnection()
        }
    }

    private var statusColor: Color {
        switch settings.provider {
        case .appleIntelligence:
            return settings.isAppleIntelligenceAvailable ? .green : .orange
        case .ollama:
            return ollamaService.isConnected ? .green : .red
        default:
            return settings.isAvailable(settings.provider) ? .green : .orange
        }
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @Environment(TranslationHistoryStore.self) private var historyStore
    @Environment(LearningProgressStore.self) private var learningStore

    private let explanationCache = WordExplanationCacheStore.shared

    @State private var showingClearVocabularyAlert: Bool = false
    @State private var showingClearHistoryAlert: Bool = false
    @State private var showingResetProgressAlert: Bool = false
    @State private var showingClearExplanationCacheAlert: Bool = false

    var body: some View {
        List {
            Section("Statistics") {
                HStack {
                    Text("Saved Words")
                    Spacer()
                    Text("\(savedTermsStore.terms.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("History Entries")
                    Spacer()
                    Text("\(historyStore.entries.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Learning Progress")
                    Spacer()
                    Text("\(learningStore.progress.count) cards")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Cached AI Explanations")
                    Spacer()
                    Text("\(explanationCache.count)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Clear Data") {
                Button(role: .destructive) {
                    showingClearVocabularyAlert = true
                } label: {
                    Text("Clear All Vocabulary")
                }
                .disabled(savedTermsStore.terms.isEmpty)

                Button(role: .destructive) {
                    showingClearHistoryAlert = true
                } label: {
                    Text("Clear Translation History")
                }
                .disabled(historyStore.entries.isEmpty)

                Button(role: .destructive) {
                    showingResetProgressAlert = true
                } label: {
                    Text("Reset Learning Progress")
                }
                .disabled(learningStore.progress.isEmpty)

                Button(role: .destructive) {
                    showingClearExplanationCacheAlert = true
                } label: {
                    Text("Clear Cached AI Explanations")
                }
                .disabled(explanationCache.isEmpty)
            }
        }
        .navigationTitle("Manage Data")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Clear Vocabulary", isPresented: $showingClearVocabularyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                savedTermsStore.clear()
            }
        } message: {
            Text("This will delete all \(savedTermsStore.terms.count) saved words. This action cannot be undone.")
        }
        .alert("Clear History", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                historyStore.clear()
            }
        } message: {
            Text("This will delete all \(historyStore.entries.count) history entries. This action cannot be undone.")
        }
        .alert("Reset Progress", isPresented: $showingResetProgressAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                learningStore.resetProgress()
            }
        } message: {
            Text("This will reset all learning progress. This action cannot be undone.")
        }
        .alert("Clear Explanation Cache", isPresented: $showingClearExplanationCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                explanationCache.clear()
            }
        } message: {
            Text("This will delete \(explanationCache.count) saved AI explanations. They will be regenerated the next time you open those words.")
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App icon and name
                VStack(spacing: 12) {
                    // character.book.closed.fill.zh needs iOS 18+; this
                    // variant exists on every supported OS.
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.tint)

                    Text("SwiftMandarin")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(verbatim: "\(L("Version")) \(AppConfig.appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                Divider()
                    .padding(.horizontal)

                // Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.headline)

                    Text("SwiftMandarin is a modern Mandarin Chinese translation and learning app built with SwiftUI for iOS 17 and later. It features real-time translation, vocabulary management, flashcard learning with spaced repetition, and a comprehensive phrase library.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    Text("Features")
                        .font(.headline)

                    FeatureRow(icon: "character.bubble", title: "Translation", description: "Bidirectional English-Chinese translation with pinyin")
                    FeatureRow(icon: "text.book.closed", title: "Vocabulary", description: "Save and organize words you're learning")
                    FeatureRow(icon: "brain.head.profile", title: "Flashcards", description: "Learn with spaced repetition")
                    FeatureRow(icon: "quote.bubble", title: "Phrases", description: "Common phrases organized by category")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Credits
                VStack(alignment: .leading, spacing: 8) {
                    Text("Credits")
                        .font(.headline)

                    Text("Built with ❤️ using SwiftUI")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Translation & AI powered by Apple Translation, on-device Ollama, and configured cloud providers including OpenAI, Claude, DeepSeek, and Qwen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MoreView()
        .environment(SavedTermsStore.shared)
        .environment(TranslationHistoryStore.shared)
        .environment(LearningProgressStore.shared)
}
