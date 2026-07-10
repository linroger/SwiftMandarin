//
//  PhrasesView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI

/// Common phrases organized by category
struct PhrasesView: View {
    @State private var searchText: String = ""
    @State private var selectedCategory: PhraseCategory?
    @State private var selectedPhrase: Phrase?
    
    private var filteredCategories: [PhraseCategory] {
        if searchText.isEmpty {
            return PhraseCategory.allCategories
        }
        
        return PhraseCategory.allCategories.compactMap { category in
            let filteredPhrases = category.phrases.filter { phrase in
                phrase.chinese.localizedCaseInsensitiveContains(searchText) ||
                phrase.pinyin.localizedCaseInsensitiveContains(searchText) ||
                phrase.english.localizedCaseInsensitiveContains(searchText)
            }
            
            guard !filteredPhrases.isEmpty else { return nil }
            return PhraseCategory(name: category.name, icon: category.icon, phrases: filteredPhrases)
        }
    }
    
    // No own NavigationStack: this screen is presented inside an ambient
    // navigation container (Study hub push on iOS, split-view detail on macOS).
    // A nested stack broke `.searchable` on iOS. See VocabularyView for detail.
    var body: some View {
            List {
                ForEach(filteredCategories) { category in
                    Section {
                        ForEach(category.phrases) { phrase in
                            PhraseRow(phrase: phrase)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedPhrase = phrase
                                }
                        }
                    } header: {
                        // Category names are data strings; route them through
                        // the catalog so headers follow the language toggle.
                        Label {
                            Text(LocalizedStringKey(category.name))
                        } icon: {
                            Image(systemName: category.icon)
                        }
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .navigationTitle("Phrases")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .searchable(text: $searchText, prompt: "Search phrases")
            .sheet(item: $selectedPhrase) { phrase in
                PhraseDetailSheet(phrase: phrase)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .localizedSurface()
            }
    }
}

// MARK: - Phrase Row

struct PhraseRow: View {
    let phrase: Phrase

    /// The learning-language side leads (中文 UI → English headline with
    /// English narration; English UI → Chinese headline + pinyin).
    private var learningChinese: Bool { LocalizationManager.shared.learningIsChinese }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if learningChinese {
                    Text(phrase.chinese)
                        .font(.headline)

                    Text(PinyinConverter.coloredPinyin(phrase.chinese))
                        .font(.subheadline)

                    Text(phrase.english)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(phrase.english)
                        .font(.headline)

                    Text(phrase.chinese)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                if learningChinese {
                    SpeechService.speakChinese(phrase.chinese)
                } else {
                    SpeechService.speakEnglish(phrase.english)
                }
            } label: {
                Image(systemName: "speaker.wave.2")
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Phrase Detail Sheet

struct PhraseDetailSheet: View {
    let phrase: Phrase
    @Environment(\.dismiss) private var dismiss
    @Environment(SavedTermsStore.self) private var savedTermsStore

    /// The learning-language side leads (中文 UI → English big, Chinese small;
    /// English UI → Chinese big + pinyin, English small).
    private var learningChinese: Bool { LocalizationManager.shared.learningIsChinese }

    private var headlineText: String { learningChinese ? phrase.chinese : phrase.english }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Large display
                    VStack(spacing: 12) {
                        Text(headlineText)
                            .font(.system(size: 36, weight: .medium))
                            .multilineTextAlignment(.center)

                        if learningChinese {
                            Text(PinyinConverter.coloredPinyin(phrase.chinese))
                                .font(.title3)
                        }

                        Text(learningChinese ? phrase.english : phrase.chinese)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Actions
                    HStack(spacing: 24) {
                        Button {
                            if learningChinese {
                                SpeechService.speakChinese(phrase.chinese)
                            } else {
                                SpeechService.speakEnglish(phrase.english)
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.title2)
                                Text("Speak")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)

                        Button {
                            ClipboardService.copy(headlineText)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.title2)
                                Text("Copy")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            let term = SavedTerm(
                                chinese: phrase.chinese,
                                pinyin: phrase.pinyin,
                                definition: phrase.english,
                                partOfSpeech: "phrase"
                            )
                            savedTermsStore.add(term)
                            dismiss()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "bookmark")
                                    .font(.title2)
                                Text("Save")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Usage note if available
                    if let note = phrase.usageNote {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Usage Note")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            Text(note)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Phrase")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Phrase Model

struct Phrase: Identifiable, Hashable {
    let id = UUID()
    let chinese: String
    let pinyin: String
    let english: String
    let usageNote: String?
    
    init(chinese: String, english: String, usageNote: String? = nil) {
        self.chinese = chinese
        self.pinyin = PinyinConverter.convert(chinese)
        self.english = english
        self.usageNote = usageNote
    }
}

// MARK: - Phrase Category

struct PhraseCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let phrases: [Phrase]
    
    static let allCategories: [PhraseCategory] = [
        PhraseCategory(name: "Greetings", icon: "hand.wave", phrases: [
            Phrase(chinese: "你好", english: "Hello"),
            Phrase(chinese: "早上好", english: "Good morning"),
            Phrase(chinese: "晚上好", english: "Good evening"),
            Phrase(chinese: "晚安", english: "Good night"),
            Phrase(chinese: "再见", english: "Goodbye"),
            Phrase(chinese: "好久不见", english: "Long time no see"),
            Phrase(chinese: "最近怎么样？", english: "How have you been?"),
        ]),
        
        PhraseCategory(name: "Common Expressions", icon: "bubble.left.and.bubble.right", phrases: [
            Phrase(chinese: "谢谢", english: "Thank you"),
            Phrase(chinese: "不客气", english: "You're welcome"),
            Phrase(chinese: "对不起", english: "Sorry"),
            Phrase(chinese: "没关系", english: "It's okay / No problem"),
            Phrase(chinese: "请", english: "Please"),
            Phrase(chinese: "是的", english: "Yes"),
            Phrase(chinese: "不是", english: "No"),
            Phrase(chinese: "好的", english: "Okay / Alright"),
        ]),
        
        PhraseCategory(name: "Questions", icon: "questionmark.circle", phrases: [
            Phrase(chinese: "你叫什么名字？", english: "What is your name?"),
            Phrase(chinese: "这是什么？", english: "What is this?"),
            Phrase(chinese: "多少钱？", english: "How much does it cost?"),
            Phrase(chinese: "在哪里？", english: "Where is it?"),
            Phrase(chinese: "为什么？", english: "Why?"),
            Phrase(chinese: "什么时候？", english: "When?"),
            Phrase(chinese: "怎么走？", english: "How do I get there?"),
        ]),
        
        PhraseCategory(name: "Dining", icon: "fork.knife", phrases: [
            Phrase(chinese: "我饿了", english: "I'm hungry"),
            Phrase(chinese: "我渴了", english: "I'm thirsty"),
            Phrase(chinese: "菜单", english: "Menu"),
            Phrase(chinese: "买单", english: "Bill please", usageNote: "Used when asking for the check at a restaurant"),
            Phrase(chinese: "好吃", english: "Delicious"),
            Phrase(chinese: "干杯", english: "Cheers!", usageNote: "Literally means 'dry cup' - drink up!"),
        ]),
        
        PhraseCategory(name: "Travel", icon: "airplane", phrases: [
            Phrase(chinese: "机场", english: "Airport"),
            Phrase(chinese: "酒店", english: "Hotel"),
            Phrase(chinese: "厕所在哪里？", english: "Where is the bathroom?"),
            Phrase(chinese: "我迷路了", english: "I'm lost"),
            Phrase(chinese: "帮帮我", english: "Help me"),
            Phrase(chinese: "出租车", english: "Taxi"),
            Phrase(chinese: "地铁站", english: "Subway station"),
        ]),
        
        PhraseCategory(name: "Numbers", icon: "number", phrases: [
            Phrase(chinese: "一", english: "One (1)"),
            Phrase(chinese: "二", english: "Two (2)"),
            Phrase(chinese: "三", english: "Three (3)"),
            Phrase(chinese: "四", english: "Four (4)"),
            Phrase(chinese: "五", english: "Five (5)"),
            Phrase(chinese: "六", english: "Six (6)"),
            Phrase(chinese: "七", english: "Seven (7)"),
            Phrase(chinese: "八", english: "Eight (8)"),
            Phrase(chinese: "九", english: "Nine (9)"),
            Phrase(chinese: "十", english: "Ten (10)"),
            Phrase(chinese: "百", english: "Hundred (100)"),
            Phrase(chinese: "千", english: "Thousand (1000)"),
        ]),
        
        PhraseCategory(name: "Time", icon: "clock", phrases: [
            Phrase(chinese: "今天", english: "Today"),
            Phrase(chinese: "明天", english: "Tomorrow"),
            Phrase(chinese: "昨天", english: "Yesterday"),
            Phrase(chinese: "现在", english: "Now"),
            Phrase(chinese: "等一下", english: "Wait a moment"),
            Phrase(chinese: "几点了？", english: "What time is it?"),
        ]),
    ]
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PhrasesView()
            .environment(SavedTermsStore.shared)
    }
}
