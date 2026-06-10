//
//  MoreView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI
import Ollama

/// More tab containing History, Settings, and About
struct MoreView: View {
    @State private var showingHistory: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showingAbout: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("Translation History", systemImage: "clock")
                    }
                    
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
                
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    
                    Link(destination: URL(string: "https://www.apple.com/privacy/")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }
                
                Section {
                    Link(destination: URL(string: "https://apps.apple.com/app/id123456789?action=write-review")!) {
                        Label("Rate App", systemImage: "star")
                    }
                    
                    ShareLink(item: URL(string: "https://apps.apple.com/app/id123456789")!) {
                        Label("Share App", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("More")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

// MARK: - History View

struct HistoryView: View {
    @Environment(TranslationHistoryStore.self) private var historyStore
    @State private var searchText: String = ""
    
    private var filteredEntries: [TranslationHistoryEntry] {
        if searchText.isEmpty {
            return historyStore.entries
        }
        return historyStore.entries.filter { entry in
            entry.source.localizedCaseInsensitiveContains(searchText) ||
            entry.target.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        Group {
            if historyStore.entries.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "clock")
                } description: {
                    Text("Your translation history will appear here")
                }
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        HistoryRow(entry: entry)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    historyStore.remove(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #endif
            }
        }
        .navigationTitle("History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchText, prompt: "Search history")
        .toolbar {
            if !historyStore.entries.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        historyStore.clear()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let entry: TranslationHistoryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.direction.sourceLanguageName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Text(entry.direction.targetLanguageName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Text(entry.source)
                .font(.subheadline)
                .lineLimit(2)
            
            Text(entry.target)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("autoTranslate") private var autoTranslate: Bool = false
    @AppStorage("autoSpeak") private var autoSpeak: Bool = false
    @AppStorage("showPinyin") private var showPinyin: Bool = true
    @AppStorage("pinyinPosition") private var pinyinPosition: String = "above"
    @AppStorage("toneColors") private var toneColors: Bool = true
    @AppStorage("defaultDirection") private var defaultDirection: String = TranslationDirection.englishToChinese.rawValue
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true
    @AppStorage("fontSize") private var fontSize: Double = 1.0
    @AppStorage("translateOnPaste") private var translateOnPaste: Bool = true
    @AppStorage("copyTranslationAutomatically") private var copyTranslationAutomatically: Bool = false
    @AppStorage("saveToHistoryAutomatically") private var saveToHistoryAutomatically: Bool = true
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
                NavigationLink {
                    AISettingsDetailView()
                } label: {
                    HStack {
                        Label("AI Provider", systemImage: "cpu")
                        Spacer()
                        Text(AIModelSettings.shared.provider.displayName)
                            .foregroundStyle(.secondary)
                            .fitSingleLine(0.8)
                    }
                }
            } header: {
                Text("AI")
            } footer: {
                Text("Configure Apple Intelligence, Ollama, or a cloud provider for AI-powered features.")
            }
            
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
                    Text("Text Size")
                    Slider(value: $fontSize, in: 0.8...1.4, step: 0.1) {
                        Text("Text Size")
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
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            } header: {
                Text("Feedback")
            }
            
            Section {
                NavigationLink {
                    DataManagementView()
                } label: {
                    Text("Manage Data")
                }
            } header: {
                Text("Data")
            }
        }
        .navigationTitle("Settings")
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
    
    @State private var showingClearVocabularyAlert: Bool = false
    @State private var showingClearHistoryAlert: Bool = false
    @State private var showingResetProgressAlert: Bool = false
    
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
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App icon and name
                VStack(spacing: 12) {
                    Image(systemName: "character.book.closed.fill.zh")
                        .font(.system(size: 80))
                        .foregroundStyle(.tint)
                    
                    Text("SwiftMandarin")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
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
                    
                    Text("SwiftMandarin is a modern Mandarin Chinese translation and learning app built with SwiftUI for iOS 26. It features real-time translation, vocabulary management, flashcard learning with spaced repetition, and a comprehensive phrase library.")
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
                    
                    Text("Translation powered by Apple Translation API")
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
    NavigationStack {
        MoreView()
    }
    .environment(SavedTermsStore.shared)
    .environment(TranslationHistoryStore.shared)
    .environment(LearningProgressStore.shared)
}
