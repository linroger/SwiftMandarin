//
//  MacOSSettingsView.swift
//  SwiftMandarin
//
//  Polished macOS Settings window with comprehensive customization options
//

import SwiftUI
import Ollama

#if os(macOS)
/// macOS-optimized Settings view with tabbed interface
struct MacOSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AISettingsTab()
                .tabItem {
                    Label("AI", systemImage: "cpu")
                }

            AIAudioSettingsView()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }
            
            TranslationSettingsTab()
                .tabItem {
                    Label("Translation", systemImage: "character.bubble")
                }
            
            AppearanceSettingsTab()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            LearningSettingsTab()
                .tabItem {
                    Label("Learning", systemImage: "brain.head.profile")
                }
            
            DataSettingsTab()
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
        }
        .frame(minWidth: 500, idealWidth: 550, minHeight: 400, idealHeight: 500)
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = false
    @AppStorage("showDockIcon") private var showDockIcon: Bool = true
    @AppStorage("globalHotkey") private var globalHotkey: String = "⌘⇧T"
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

            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                Toggle("Show in Menu Bar", isOn: $showInMenuBar)
                Toggle("Show Dock Icon", isOn: $showDockIcon)
            } header: {
                Text("Startup")
            }
            
            Section {
                LabeledContent("Global Hotkey") {
                    Text(globalHotkey)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.quaternary)
                        )
                }
            } header: {
                Text("Shortcuts")
            }
            
            Section {
                LabeledContent("Version") {
                    Text(verbatim: AppConfig.appVersion)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Build") {
                    Text(verbatim: AppConfig.buildNumber)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - AI Settings Tab

struct AISettingsTab: View {
    @State private var settings = AIModelSettings.shared
    @State private var ollamaService = OllamaService.shared

    var body: some View {
        Form {
            // Provider Selection
            Section {
                Picker("AI Provider", selection: $settings.provider) {
                    ForEach(AIProvider.allCases) { provider in
                        HStack {
                            ProviderIcon(provider: provider, size: 16)
                            Text(provider.displayName)
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.menu)

                // Status indicator
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(settings.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("AI Provider")
            } footer: {
                Text("Choose Apple Intelligence (on-device), Ollama (local server), or a cloud provider (OpenAI, Claude, DeepSeek, Doubao, Qwen, Kimi, Zhipu, MiniMax).")
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

            // Batch AI word analysis (background, cancellable, live progress).
            // Shares state with the iOS hub via BatchExplanationController.shared,
            // so progress survives closing and reopening this Settings window.
            BatchAIAnalysisControls()
        }
        .formStyle(.grouped)
        .padding()
        .task {
            // Check connection and load models on appear
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

// MARK: - Translation Settings Tab

struct TranslationSettingsTab: View {
    @AppStorage("autoTranslate") private var autoTranslate: Bool = false
    @AppStorage("autoSpeak") private var autoSpeak: Bool = false
    @AppStorage("defaultDirection") private var defaultDirection: String = TranslationDirection.persistedDefault.rawValue
    @AppStorage("translateOnPaste") private var translateOnPaste: Bool = true
    @AppStorage("copyTranslationAutomatically") private var copyTranslationAutomatically: Bool = false
    @AppStorage("saveToHistoryAutomatically") private var saveToHistoryAutomatically: Bool = true
    @AppStorage("maxHistoryEntries") private var maxHistoryEntries: Double = 100
    
    var body: some View {
        Form {
            Section {
                Picker("Default Direction", selection: $defaultDirection) {
                    ForEach(TranslationDirection.allCases) { direction in
                        Text(direction.label).tag(direction.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                
                Toggle("Auto-Translate While Typing", isOn: $autoTranslate)
                Toggle("Translate on Paste", isOn: $translateOnPaste)
            } header: {
                Text("Translation Behavior")
            }
            
            Section {
                Toggle("Auto-Speak Translations", isOn: $autoSpeak)
                Toggle("Copy Translation to Clipboard", isOn: $copyTranslationAutomatically)
            } header: {
                Text("Output")
            }
            
            Section {
                Toggle("Save Translations to History", isOn: $saveToHistoryAutomatically)
                
                LabeledContent("Max History Entries") {
                    Slider(value: $maxHistoryEntries, in: 50...500, step: 50) {
                        Text("Max Entries")
                    }
                    Text("\(Int(maxHistoryEntries))")
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            } header: {
                Text("History")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Settings Tab

struct AppearanceSettingsTab: View {
    @AppStorage("showPinyin") private var showPinyin: Bool = true
    @AppStorage("pinyinPosition") private var pinyinPosition: String = "above"
    // Sizes the vocabulary headword, which is Chinese for an English
    // speaker and English for a Mandarin one. The storage key keeps its
    // original name so existing preferences survive.
    @AppStorage("vocabularyChineseFontSize") private var headwordFontSize: Double = 20
    @AppStorage("chineseFont") private var chineseFont: String = "System"
    @AppStorage("toneColors") private var toneColors: Bool = true
    @AppStorage("wordBorders") private var wordBorders: Bool = true
    @AppStorage("compactMode") private var compactMode: Bool = false
    @AppStorage("vocabularyDetailUsesInspector") private var vocabularyDetailUsesInspector: Bool = true
    @State private var prefs = AppPreferences.shared
    @State private var localization = LocalizationManager.shared

    var body: some View {
        Form {
            // Pinyin is scaffolding for reading Chinese, so this whole section
            // belongs to the learner who is decoding it. A native Mandarin
            // reader studying English sees Typography and Layout only.
            if localization.learningIsChinese {
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
                } header: {
                    Text("Pinyin Display")
                }
            }

            Section {
                LabeledContent("Vocabulary Text Size") {
                    Slider(value: $headwordFontSize, in: 14...40, step: 2) {
                        Text("Size")
                    }
                    Text(verbatim: "\(Int(headwordFontSize)) pt")
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }

                // The Chinese typeface only affects Han glyphs, so it is
                // offered to the learner who spends their time reading them.
                if localization.learningIsChinese {
                    Picker("Chinese Font", selection: $chineseFont) {
                        Text("System Default").tag("System")
                        Text("PingFang SC").tag("PingFang SC")
                        Text("STSong").tag("STSong")
                        Text("Kaiti SC").tag("Kaiti SC")
                    }
                }
            } header: {
                Text("Typography")
            }
            
            Section {
                Toggle("Show Word Borders", isOn: $wordBorders)
                Toggle("Compact Mode", isOn: $compactMode)
            } header: {
                Text("Layout")
            }

            Section {
                Toggle("Use Inspector for Vocabulary Details", isOn: $vocabularyDetailUsesInspector)
            } header: {
                Text("Vocabulary")
            } footer: {
                Text("Turn off to use popup details instead of the inspector.")
            }

            Section {
                LabeledContent("Speaking Speed") {
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
                    Button {
                        SpeechService.speakAuto(speechSample)
                    } label: {
                        Label("Preview", systemImage: "speaker.wave.2.fill")
                    }
                }
            } header: {
                Text("Speech")
            } footer: {
                Text("Applies to every read-aloud in the app.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// Sample sentence for previewing the speech rate, in the learning language.
    private var speechSample: String {
        LocalizationManager.shared.learningIsChinese ? "你好，很高兴认识你。" : "Hello, nice to meet you."
    }
}

// MARK: - Learning Settings Tab

struct LearningSettingsTab: View {
    @AppStorage("dailyGoal") private var dailyGoal: Double = 20
    @AppStorage("reviewReminders") private var reviewReminders: Bool = true
    @AppStorage("reminderTime") private var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true
    @AppStorage("showStreak") private var showStreak: Bool = true
    @AppStorage("autoAdvance") private var autoAdvance: Bool = true
    @AppStorage("showHints") private var showHints: Bool = true
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Daily Goal") {
                    Slider(value: $dailyGoal, in: 5...100, step: 5) {
                        Text("Goal")
                    }
                    Text("\(Int(dailyGoal)) cards")
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                }
                
                Toggle("Show Streak", isOn: $showStreak)
            } header: {
                Text("Goals")
            }
            
            Section {
                Toggle("Review Reminders", isOn: $reviewReminders)
                
                DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .disabled(!reviewReminders)
            } header: {
                Text("Notifications")
            }
            
            Section {
                Toggle("Auto-Advance After Review", isOn: $autoAdvance)
                Toggle("Show Hints", isOn: $showHints)
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            } header: {
                Text("Flashcards")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Data Settings Tab

struct DataSettingsTab: View {
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @Environment(TranslationHistoryStore.self) private var historyStore
    @Environment(LearningProgressStore.self) private var learningStore
    
    @State private var showingClearVocabularyAlert: Bool = false
    @State private var showingClearHistoryAlert: Bool = false
    @State private var showingResetProgressAlert: Bool = false
    @State private var showingImportResult: Bool = false
    @State private var importResult: ImportResult?
    @State private var selectedExportFormat: VocabularyExportFormat = .json
    @State private var includeAIAnalysis: Bool = true
    @State private var showExportSuccess: Bool = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Saved Words") {
                    Text("\(savedTermsStore.terms.count)")
                        .foregroundStyle(.secondary)
                }
                
                LabeledContent("History Entries") {
                    Text("\(historyStore.entries.count)")
                        .foregroundStyle(.secondary)
                }
                
                LabeledContent("Flashcards") {
                    Text("\(learningStore.progress.count)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Statistics")
            }
            
            Section {
                Picker("Export Format", selection: $selectedExportFormat) {
                    ForEach(VocabularyExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Include AI Analysis", isOn: $includeAIAnalysis)

                Button {
                    VocabularyImportExportService.shared.exportToFile(
                        terms: savedTermsStore.terms,
                        format: selectedExportFormat,
                        includeAIAnalysis: includeAIAnalysis
                    )
                    showExportSuccess = true
                } label: {
                    Label("Export Vocabulary...", systemImage: "square.and.arrow.up")
                }
                .disabled(savedTermsStore.terms.isEmpty)
                
                Button {
                    VocabularyImportExportService.shared.importFromFile(into: savedTermsStore) { result in
                        if let result = result {
                            importResult = result
                            showingImportResult = true
                        }
                    }
                } label: {
                    Label("Import Vocabulary...", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Backup & Restore")
            } footer: {
                Text("JSON format is recommended for backup. Duplicate words will be skipped during import.")
            }
            
            Section {
                Button("Clear Vocabulary", role: .destructive) {
                    showingClearVocabularyAlert = true
                }
                .disabled(savedTermsStore.terms.isEmpty)
                
                Button("Clear History", role: .destructive) {
                    showingClearHistoryAlert = true
                }
                .disabled(historyStore.entries.isEmpty)
                
                Button("Reset Learning Progress", role: .destructive) {
                    showingResetProgressAlert = true
                }
                .disabled(learningStore.progress.isEmpty)
            } header: {
                Text("Clear Data")
            }
        }
        .formStyle(.grouped)
        .padding()
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
        .alert("Import Complete", isPresented: $showingImportResult) {
            Button("OK", role: .cancel) { }
        } message: {
            // `??` binds the literal as a plain `String`, so `Text` renders it
            // verbatim and this fallback stayed English in the Chinese UI.
            Text(importResult?.summary ?? String(localized: "Import completed", bundle: .appLanguage))
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your vocabulary has been exported successfully.")
        }
    }
}

// MARK: - Preview

#Preview {
    MacOSSettingsView()
        .environment(SavedTermsStore.shared)
        .environment(TranslationHistoryStore.shared)
        .environment(LearningProgressStore.shared)
}
#endif
