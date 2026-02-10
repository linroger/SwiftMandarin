//
//  MacOSSettingsView.swift
//  SwiftMandarin
//
//  Polished macOS Settings window with comprehensive customization options
//

import SwiftUI

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
        .frame(width: 520, height: 480)
        .fixedSize()
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = false
    @AppStorage("showDockIcon") private var showDockIcon: Bool = true
    @AppStorage("globalHotkey") private var globalHotkey: String = "⌘⇧T"
    
    var body: some View {
        ScrollView {
            Form {
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
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    LabeledContent("Build") {
                        Text("2026.02.11")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .formStyle(.grouped)
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Translation Settings Tab

struct TranslationSettingsTab: View {
    @AppStorage("autoTranslate") private var autoTranslate: Bool = false
    @AppStorage("autoSpeak") private var autoSpeak: Bool = false
    @AppStorage("defaultDirection") private var defaultDirection: String = TranslationDirection.englishToChinese.rawValue
    @AppStorage("translateOnPaste") private var translateOnPaste: Bool = true
    @AppStorage("copyTranslationAutomatically") private var copyTranslationAutomatically: Bool = false
    @AppStorage("saveToHistoryAutomatically") private var saveToHistoryAutomatically: Bool = true
    @AppStorage("maxHistoryEntries") private var maxHistoryEntries: Double = 100
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    Picker("Default Direction", selection: $defaultDirection) {
                        ForEach(TranslationDirection.allCases) { direction in
                            Text(direction.label).tag(direction.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Auto-Translate While Typing", isOn: $autoTranslate)
                    
                    Text("When enabled, translation runs automatically as you type.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
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
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Appearance Settings Tab

struct AppearanceSettingsTab: View {
    @AppStorage("showPinyin") private var showPinyin: Bool = true
    @AppStorage("pinyinPosition") private var pinyinPosition: String = "above"
    @AppStorage("fontSize") private var fontSize: Double = 1.0
    @AppStorage("chineseFont") private var chineseFont: String = "System"
    @AppStorage("toneColors") private var toneColors: Bool = true
    @AppStorage("wordBorders") private var wordBorders: Bool = true
    @AppStorage("compactMode") private var compactMode: Bool = false
    
    var body: some View {
        ScrollView {
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
                } header: {
                    Text("Pinyin Display")
                }
                
                Section {
                    LabeledContent("Text Size") {
                        Slider(value: $fontSize, in: 0.8...1.6, step: 0.1) {
                            Text("Size")
                        }
                        Text("\(Int(fontSize * 100))%")
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    
                    Picker("Chinese Font", selection: $chineseFont) {
                        Text("System Default").tag("System")
                        Text("PingFang SC").tag("PingFang SC")
                        Text("STSong").tag("STSong")
                        Text("Kaiti SC").tag("Kaiti SC")
                    }
                } header: {
                    Text("Typography")
                }
                
                Section {
                    Toggle("Show Word Borders", isOn: $wordBorders)
                    Toggle("Compact Mode", isOn: $compactMode)
                    
                    Text("Compact mode reduces spacing for smaller windows.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Layout")
                }
            }
            .formStyle(.grouped)
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
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
        ScrollView {
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
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
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
    @State private var showingExportSheet: Bool = false
    @State private var showingImportSheet: Bool = false
    
    var body: some View {
        ScrollView {
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
                    Button("Export Data...") {
                        showingExportSheet = true
                    }
                    
                    Button("Import Data...") {
                        showingImportSheet = true
                    }
                } header: {
                    Text("Backup")
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
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
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

// MARK: - Preview

#Preview {
    MacOSSettingsView()
        .environment(SavedTermsStore.shared)
        .environment(TranslationHistoryStore.shared)
        .environment(LearningProgressStore.shared)
}
#endif
