//
//  EnglishRubyTextView.swift
//  SwiftMandarin
//
//  Word-by-word English text display with Chinese translations
//  Similar to RubyTextView but for English → Chinese
//

import SwiftUI

/// A single English word chip with translation
struct EnglishWordChip: View {
    let word: AnalyzedEnglishWord
    let showTranslation: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                // English word
                Text(word.text)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                // Chinese translation (if available)
                if showTranslation, let translation = word.translation {
                    Text(translation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Part of speech indicator
                Text(word.partOfSpeech.abbreviation)
                    .font(.caption2)
                    .foregroundStyle(word.partOfSpeech.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(word.partOfSpeech.color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(word.partOfSpeech.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Word detail sheet for English words
struct EnglishWordDetailSheet: View {
    let word: AnalyzedEnglishWord
    @Environment(\.dismiss) private var dismiss
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @State private var prefs = AppPreferences.shared

    @State private var isLoading: Bool = false
    @State private var fullTranslation: String = ""
    
    /// Keyed on whatever `saveToVocabulary` would actually store, so the
    /// button does not offer to save a word that is already in the list.
    private var isSaved: Bool {
        !storedHeadword.isEmpty && savedTermsStore.contains(chinese: storedHeadword)
    }
    
    /// Get the best available Chinese translation
    private var chineseTranslation: String {
        if !fullTranslation.isEmpty {
            return fullTranslation
        } else if let translation = word.translation, !translation.isEmpty {
            return translation
        }
        return ""
    }

    /// The learning-language side leads: 中文 UI (learning English) keeps the
    /// English word as the big headline; English UI (learning Chinese) makes
    /// the Chinese translation the headline with pinyin underneath.
    private var learningChinese: Bool { LocalizationManager.shared.learningIsChinese }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Word header — learning-language side displayed prominently
                    VStack(spacing: 12) {
                        if learningChinese {
                            // Chinese translation is what's being learned
                            if isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("正在翻译...")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }
                            } else if !chineseTranslation.isEmpty {
                                Text(chineseTranslation)
                                    .font(.system(size: 44, weight: .medium))

                                Text(PinyinConverter.coloredPinyin(chineseTranslation))
                                    .font(.title3)
                            }

                            Text(word.text)
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        } else {
                            // English word is what's being learned
                            Text(word.text)
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            if isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("正在翻译...")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }
                            } else if !chineseTranslation.isEmpty {
                                Text(chineseTranslation)
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                        }

                        // Part of speech badge
                        HStack {
                            Text(word.partOfSpeech.englishName)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(word.partOfSpeech.color)
                                )
                            
                            Text(word.partOfSpeech.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Word forms section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("词形变化")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("原形")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(word.lemma)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            
                            if word.text.lowercased() != word.lemma.lowercased() {
                                VStack(alignment: .leading) {
                                    Text("当前形式")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(word.text)
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Part of speech info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("词性说明")
                            .font(.headline)
                        
                        Text("\(word.partOfSpeech.englishName) (\(word.partOfSpeech.rawValue))")
                            .font(.body)
                        
                        if !word.partOfSpeech.examples.isEmpty {
                            Text("同类词例: \(word.partOfSpeech.examples.prefix(5).joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Narration — the learning language always; the native
                    // language additionally when dual narration is on.
                    HStack(spacing: 12) {
                        if learningChinese {
                            Button {
                                SpeechService.speakChinese(chineseTranslation)
                            } label: {
                                Label("中文", systemImage: "speaker.wave.2")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(chineseTranslation.isEmpty)

                            if prefs.dualNarration {
                                Button {
                                    SpeechService.speakEnglish(word.text)
                                } label: {
                                    Label("English", systemImage: "speaker.wave.2")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            Button {
                                SpeechService.speakEnglish(word.text)
                            } label: {
                                Label("English", systemImage: "speaker.wave.2")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            if prefs.dualNarration {
                                Button {
                                    SpeechService.speakChinese(chineseTranslation)
                                } label: {
                                    Label("中文", systemImage: "speaker.wave.2")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(chineseTranslation.isEmpty)
                            }
                        }
                    }

                    // Save action
                    Button {
                        saveToVocabulary()
                    } label: {
                        Label(isSaved ? "已保存" : "保存到词汇本", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                            .fitSingleLine()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    // A missing Chinese translation blocks the save only when
                    // Chinese is what gets stored. A Mandarin speaker studying
                    // English can save the English headword whether or not the
                    // gloss has arrived yet.
                    .disabled(isSaved || storedHeadword.isEmpty)
                }
                .padding()
            }
            .navigationTitle("单词详情")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                // Auto-translate when sheet appears if no translation available
                if chineseTranslation.isEmpty {
                    await translateWord()
                }
            }
        }
    }
    
    private func translateWord() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Translate English word to Chinese
            let translation = try await WordTranslationService.shared.translateToChinese(word.lemma)
            fullTranslation = translation
        } catch {
            // Handle error silently for now
            fullTranslation = word.translation ?? ""
        }
    }
    
    /// The word as it will be stored — `SavedTerm.chinese` is the *headword*
    /// slot, and the headword is always the language being studied.
    ///
    /// Storing the Chinese side unconditionally made this the odd one out
    /// among the reverse-mode writers (`ShortcutHelpers.saveEnglishPhrases`,
    /// `TranslateView.saveKeyTerm`), so the same word saved from here and from
    /// there produced two rows that render identically — duplicate-detection
    /// keys off the headword, and the two headwords disagreed.
    private var storedHeadword: String {
        learningChinese ? chineseTranslation : englishForm
    }

    private var storedDefinition: String {
        learningChinese ? englishForm : chineseTranslation
    }

    /// The English word, with its dictionary form appended when it differs, so
    /// an inflected token still carries the lemma a learner would look up.
    private var englishForm: String {
        word.lemma.caseInsensitiveCompare(word.text) == .orderedSame
            ? word.text
            : "\(word.text) (\(word.lemma))"
    }

    private func saveToVocabulary() {
        let headword = storedHeadword
        guard !headword.isEmpty else { return }
        savedTermsStore.add(
            SavedTerm(
                // Pinyin belongs to a Chinese headword only; an English one
                // takes its reading from an AI explanation, as IPA.
                chinese: headword,
                pinyin: learningChinese ? PinyinConverter.convert(headword) : "",
                definition: storedDefinition,
                partOfSpeech: word.partOfSpeech.rawValue
            )
        )
    }
}

/// Inline punctuation display for English text (no chip styling)
struct EnglishPunctuationView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.title3)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
    }
}

/// Ruby-style text view for English with word-by-word translations
struct EnglishRubyTextView: View {
    let words: [AnalyzedEnglishWord]
    let showTranslations: Bool
    let onWordTap: (AnalyzedEnglishWord) -> Void
    
    init(words: [AnalyzedEnglishWord], showTranslations: Bool = true, onWordTap: @escaping (AnalyzedEnglishWord) -> Void) {
        self.words = words
        self.showTranslations = showTranslations
        self.onWordTap = onWordTap
    }
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(words) { word in
                if word.isPunctuation {
                    // Display punctuation inline without chip styling
                    EnglishPunctuationView(text: word.text)
                } else {
                    EnglishWordChip(
                        word: word,
                        showTranslation: showTranslations,
                        onTap: { onWordTap(word) }
                    )
                }
            }
        }
    }
}

// MARK: - Preview
// Note: FlowLayout is defined in TranslateView.swift and reused here

#Preview {
    let sampleWords = [
        AnalyzedEnglishWord(text: "The", lemma: "the", partOfSpeech: .determiner, translation: "这/那"),
        AnalyzedEnglishWord(text: "cat", lemma: "cat", partOfSpeech: .noun, translation: "猫"),
        AnalyzedEnglishWord(text: "is", lemma: "be", partOfSpeech: .verb, translation: "是"),
        AnalyzedEnglishWord(text: "sleeping", lemma: "sleep", partOfSpeech: .verb, translation: "睡觉"),
        AnalyzedEnglishWord(text: "on", lemma: "on", partOfSpeech: .preposition, translation: "在...上"),
        AnalyzedEnglishWord(text: "the", lemma: "the", partOfSpeech: .determiner, translation: "这/那"),
        AnalyzedEnglishWord(text: "sofa", lemma: "sofa", partOfSpeech: .noun, translation: "沙发")
    ]
    
    EnglishRubyTextView(words: sampleWords, showTranslations: true) { word in
        print("Tapped: \(word.text)")
    }
    .padding()
}
