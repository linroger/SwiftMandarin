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
    /// `NavigationPath`, not `[MoreRoute]`: Reader, Practice, and Conversation
    /// push pages of their own through item destinations once they are here.
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                // Liquid Glass sections over the app's page backdrop, like the
                // other hubs (Home, Study). A system List draws its grouped rows
                // opaque, so the hub lays its rows out itself.
                VStack(alignment: .leading, spacing: 22) {
                    headerSection
                    learningSection
                    quickSetupSection
                    settingsSection
                    aboutSection
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: SMTheme.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .smPageBackground()
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
        MoreSection("Learning Tools") {
            NavigationLink(value: MoreRoute.learn) {
                MoreRow(AppTab.learn.titleKey, systemImage: AppTab.learn.icon)
            }
            MoreDivider()
            NavigationLink(value: MoreRoute.practice) {
                MoreRow(AppTab.practice.titleKey, systemImage: AppTab.practice.icon)
            }
            MoreDivider()
            NavigationLink(value: MoreRoute.conversation) {
                MoreRow(AppTab.conversation.titleKey, systemImage: AppTab.conversation.icon)
            }
            MoreDivider()
            NavigationLink(value: MoreRoute.reader) {
                MoreRow(AppTab.reader.titleKey, systemImage: AppTab.reader.icon)
            }
            MoreDivider()
            NavigationLink(value: MoreRoute.phrases) {
                MoreRow(AppTab.phrases.titleKey, systemImage: AppTab.phrases.icon)
            }
            MoreDivider()
            NavigationLink(value: MoreRoute.stats) {
                MoreRow(AppTab.stats.titleKey, systemImage: AppTab.stats.icon)
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 14) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 30))
                .foregroundStyle(.tint)
                .frame(width: 52, height: 52)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("SwiftMandarin")
                    .font(.headline)
                Text(verbatim: "\(L("Version")) \(AppConfig.appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .smCardSurface(cornerRadius: moreSectionCornerRadius)
        .accessibilityElement(children: .combine)
    }

    private var quickSetupSection: some View {
        MoreSection("Quick Setup") {
            MoreRow("App Language", systemImage: localization.language.iconName, showsChevron: false) {
                MoreMenuPicker(
                    titleKey: "App Language",
                    selection: $localization.language,
                    options: AppLanguage.allCases,
                    name: \.displayName,
                    systemImage: \.iconName
                )
            }
            MoreDivider()
            MoreRow("I am a…", systemImage: prefs.learnerMode.iconName, showsChevron: false) {
                MoreMenuPicker(
                    titleKey: "I am a…",
                    selection: $prefs.learnerMode,
                    options: LearnerMode.allCases,
                    name: \.displayName,
                    systemImage: \.iconName
                )
            }
        }
    }

    /// The pinyin controls inside `DisplaySettingsView` only exist for a
    /// Mandarin learner, so only their entry point advertises them. Typed
    /// explicitly rather than written inline: a literal inside a ternary is
    /// ambiguous between the localizing and verbatim initializers, and Xcode's
    /// extractor does not reliably catalog it.
    private var displaySettingsTitle: LocalizedStringKey {
        localization.learningIsChinese ? "Display & Pinyin" : "Display"
    }

    private var settingsSection: some View {
        MoreSection("Settings") {
            NavigationLink {
                GeneralSettingsView()
            } label: {
                MoreRow("General", systemImage: "gearshape")
            }
            MoreDivider()
            NavigationLink {
                AISettingsDetailView()
            } label: {
                MoreRow("AI Provider", systemImage: "cpu") {
                    Text(aiSettings.provider.displayName)
                        .foregroundStyle(.secondary)
                        .fitSingleLine(0.8)
                }
            }
            MoreDivider()
            NavigationLink {
                AIAudioSettingsView()
            } label: {
                MoreRow("AI Audio", systemImage: "waveform") {
                    Text(prefs.aiAudioEnabled ? "On" : "Off")
                        .foregroundStyle(.secondary)
                }
            }
            MoreDivider()
            NavigationLink {
                BatchAIAnalysisView()
            } label: {
                MoreRow("Batch AI Analysis", systemImage: "sparkles.rectangle.stack") {
                    // Live progress, visible even from the hub root, so the user
                    // knows a background run is still going after navigating back.
                    BatchAIAnalysisStatusBadge()
                }
            }
            MoreDivider()
            NavigationLink {
                TranslationSettingsView()
            } label: {
                MoreRow("Translation", systemImage: "character.bubble")
            }
            MoreDivider()
            NavigationLink {
                DisplaySettingsView()
            } label: {
                MoreRow(displaySettingsTitle, systemImage: "textformat")
            }
            MoreDivider()
            NavigationLink {
                DataManagementView()
            } label: {
                MoreRow("Manage Data", systemImage: "externaldrive")
            }
        }
    }

    private var aboutSection: some View {
        MoreSection("About & Support") {
            NavigationLink {
                AboutView()
            } label: {
                MoreRow("About", systemImage: "info.circle")
            }
            MoreDivider()
            Link(destination: AppConfig.privacyPolicyURL) {
                MoreRow("Privacy Policy", systemImage: "hand.raised", trailingSymbol: "arrow.up.right")
            }
            MoreDivider()
            Link(destination: AppConfig.reviewURL) {
                MoreRow("Rate App", systemImage: "star", trailingSymbol: "arrow.up.right")
            }
            MoreDivider()
            ShareLink(item: AppConfig.appStoreURL) {
                MoreRow("Share App", systemImage: "square.and.arrow.up", showsChevron: false)
            }
        }
    }
}

// MARK: - Hub building blocks

/// The corner radius of the hub's glass panels.
private let moreSectionCornerRadius: CGFloat = 22

/// A titled Liquid Glass panel of rows, the hub's stand-in for a grouped
/// list section. The rows inside stay plain, so no glass sits on glass.
private struct MoreSection<Content: View>: View {
    let titleKey: LocalizedStringKey
    @ViewBuilder var content: Content

    init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                content
            }
            .buttonStyle(MoreRowButtonStyle())
            .smCardSurface(cornerRadius: moreSectionCornerRadius)
        }
    }
}

/// One hub row: a tinted icon, its title, an optional trailing value, and
/// the disclosure chevron of a row that pushes a screen.
private struct MoreRow<Trailing: View>: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    var showsChevron = true
    var trailingSymbol = "chevron.right"
    @ViewBuilder var trailing: Trailing

    init(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        showsChevron: Bool = true,
        trailingSymbol: String = "chevron.right",
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.showsChevron = showsChevron
        self.trailingSymbol = trailingSymbol
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(titleKey)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .layoutPriority(1)
            Spacer(minLength: 8)
            trailing
            if showsChevron {
                Image(systemName: trailingSymbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

/// A row's menu picker: the current choice on one line in the row (a menu
/// picker's own label wraps a long choice over several lines and spills out
/// of the row), with every choice, its icon and a checkmark in the menu.
private struct MoreMenuPicker<Option: Hashable>: View {
    let titleKey: LocalizedStringKey
    @Binding var selection: Option
    let options: [Option]
    let name: KeyPath<Option, String>
    let systemImage: KeyPath<Option, String>

    var body: some View {
        Menu {
            Picker(titleKey, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Label(option[keyPath: name], systemImage: option[keyPath: systemImage]).tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 4) {
                Text(selection[keyPath: name])
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.tint)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(Text(titleKey))
        .accessibilityValue(Text(selection[keyPath: name]))
    }
}

/// The hairline between two rows, inset to the title like a grouped list.
private struct MoreDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 58)
    }
}

/// Plain rows that highlight while pressed, like a list cell.
private struct MoreRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.primary.opacity(0.08) : Color.clear)
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
        .scrollContentBackground(.hidden)
        .smPageBackground()
        #endif
    }
}

// MARK: - Translation Settings

struct TranslationSettingsView: View {
    @AppStorage("defaultDirection") private var defaultDirection: String = TranslationDirection.persistedDefault.rawValue
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
        .scrollContentBackground(.hidden)
        .smPageBackground()
        #endif
    }
}

// MARK: - Display Settings

struct DisplaySettingsView: View {
    @AppStorage("showPinyin") private var showPinyin: Bool = true
    @AppStorage("pinyinPosition") private var pinyinPosition: String = "above"
    @AppStorage("toneColors") private var toneColors: Bool = true
    // Sizes the vocabulary headword, which is Chinese for an English
    // speaker and English for a Mandarin one. The storage key keeps its
    // original name so existing preferences survive.
    @AppStorage("vocabularyChineseFontSize") private var headwordFontSize: Double = 20
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true
    @State private var prefs = AppPreferences.shared
    @State private var localization = LocalizationManager.shared

    /// Matches the entry point in the settings list: the pinyin controls below
    /// only exist for a Mandarin learner, so only they see the longer title.
    private var screenTitle: LocalizedStringKey {
        localization.learningIsChinese ? "Display & Pinyin" : "Display"
    }

    /// Sample sentence for previewing the speech rate, in the learning language.
    private var speechSample: String {
        localization.learningIsChinese ? "你好，很高兴认识你。" : "Hello, nice to meet you."
    }

    var body: some View {
        Form {
            Section {
                // Pinyin is scaffolding for reading Chinese. A native Mandarin
                // reader studying English never needs it, and these controls
                // would only clutter their settings with rules about a script
                // they already read — so the whole group is theirs alone.
                if localization.learningIsChinese {
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
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Vocabulary Text Size")
                        Spacer()
                        Text(verbatim: "\(Int(headwordFontSize)) pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $headwordFontSize, in: 14...40, step: 2) {
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
        .navigationTitle(screenTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .smPageBackground()
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
        .scrollContentBackground(.hidden)
        .smPageBackground()
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
        .scrollContentBackground(.hidden)
        .smPageBackground()
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

                // Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.headline)

                    // Both learner modes read this screen, so the copy here and
                    // in the feature list below describes a two-way English and
                    // Chinese app instead of framing it as Mandarin study,
                    // which excluded the Mandarin speaker studying English.
                    Text("SwiftMandarin is an English and Chinese translation and learning app for speakers of either language, built with SwiftUI for iOS 17 and later. It features real-time translation, vocabulary management, flashcard learning with spaced repetition, and a comprehensive phrase library.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SMTheme.cardPadding)
                .smCardSurface()
                .padding(.horizontal)

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    Text("Features")
                        .font(.headline)

                    FeatureRow(icon: "character.bubble", title: "Translation", description: "Translate between English and Chinese in either direction")
                    FeatureRow(icon: "text.book.closed", title: "Vocabulary", description: "Save and organize words you're learning")
                    FeatureRow(icon: "brain.head.profile", title: "Flashcards", description: "Learn with spaced repetition")
                    FeatureRow(icon: "quote.bubble", title: "Phrases", description: "Common phrases organized by category")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SMTheme.cardPadding)
                .smCardSurface()
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
                .padding(SMTheme.cardPadding)
                .smCardSurface()
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .smPageBackground()
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    // Plain `String`s render through `Text`'s verbatim initializer, so the
    // literals at each call site never reached the string catalog and the whole
    // feature list stayed English for a Mandarin reader. `LocalizedStringKey`
    // makes them extractable and translatable, exactly as `HeroActionRow` does.
    let title: LocalizedStringKey
    let description: LocalizedStringKey

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
