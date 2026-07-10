//
//  PracticeStore.swift
//  SwiftMandarin
//
//  Backing model for the Practice hub: persisted round results for the
//  multiple-choice quiz, dictation, and tone-pair drills, plus the
//  tone-confusion matrix that powers the "most confused pair" insight.
//  Also owns the shared, direction-aware question pool (`PracticeItem`)
//  so all three drills quiz the same material the same way.
//

import Foundation
import Observation
#if os(iOS)
import UIKit
#endif

// MARK: - Practice mode

/// The three drills offered by the Practice hub.
enum PracticeMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case quiz
    case dictation
    case toneDrill

    var id: String { rawValue }
}

// MARK: - Session result

/// One finished practice round: how many answers were right out of how many
/// questions, in which drill, and when.
struct PracticeSessionResult: Identifiable, Codable, Equatable {
    let id: UUID
    let mode: PracticeMode
    let score: Int
    let total: Int
    let date: Date

    /// Fraction correct (0…1); 0 for a degenerate empty round.
    var ratio: Double {
        total > 0 ? Double(score) / Double(total) : 0
    }

    /// Compact "7/10" display form used for badges and summaries.
    var scoreText: String {
        "\(score)/\(total)"
    }

    init(id: UUID = UUID(), mode: PracticeMode, score: Int, total: Int, date: Date = Date()) {
        self.id = id
        self.mode = mode
        self.score = score
        self.total = total
        self.date = date
    }

    private enum CodingKeys: String, CodingKey {
        case id, mode, score, total, date
    }

    /// Tolerant decoder: a missing or malformed field falls back to a default
    /// rather than throwing and dropping the whole stored history.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        mode = (try? c.decode(PracticeMode.self, forKey: .mode)) ?? .quiz
        score = (try? c.decode(Int.self, forKey: .score)) ?? 0
        total = (try? c.decode(Int.self, forKey: .total)) ?? 0
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date()
    }
}

// MARK: - Practice item (shared question pool)

/// A single quizzable entry with both language sides resolved up front.
/// The prompt/answer split follows the learning direction at display time
/// (English UI → Chinese prompts with English answers; 中文 UI → English
/// prompts with Mandarin answers), exactly like `SavedTerm.headlineText`.
struct PracticeItem: Identifiable, Hashable {
    /// Stable identity: the source term's UUID for vocabulary, the
    /// "builtin:…" card id for the starter deck.
    let id: String
    /// The Chinese side (empty when the entry has no Chinese text).
    let chinese: String
    /// The English side (empty when the entry has no English text).
    let english: String
    /// Tone-marked pinyin for the Chinese side ("" when unavailable).
    let pinyin: String
    let partOfSpeech: String

    /// The side in the language the user is LEARNING — shown big / spoken.
    var promptText: String {
        LocalizationManager.shared.learningIsChinese ? chinese : english
    }

    /// The side in the user's NATIVE language — the gloss they answer with.
    var answerText: String {
        LocalizationManager.shared.learningIsChinese ? english : chinese
    }

    /// Pinyin is a learner aid: only meaningful when learning Chinese.
    var showsPinyin: Bool {
        LocalizationManager.shared.learningIsChinese && !pinyin.isEmpty
    }

    /// Build from a saved vocabulary term; nil when either language side is
    /// missing (a one-sided entry can't be quizzed prompt→gloss).
    init?(term: SavedTerm) {
        let chineseSide = term.chineseSide.trimmingCharacters(in: .whitespacesAndNewlines)
        let englishSide = term.englishSide.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chineseSide.isEmpty, !englishSide.isEmpty else { return nil }
        self.id = "vocab:\(term.id.uuidString)"
        self.chinese = chineseSide
        self.english = englishSide
        let storedPinyin = term.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pinyin = storedPinyin.isEmpty ? PinyinConverter.convert(chineseSide) : storedPinyin
        self.partOfSpeech = term.partOfSpeech
    }

    /// Build from a built-in starter card. The deck ships without pinyin, so
    /// it is derived on the fly — tone drills need per-syllable tone marks.
    init(card: LearningCard) {
        self.id = card.id
        self.chinese = card.chinese
        self.english = card.english
        let cardPinyin = card.pinyin?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.pinyin = cardPinyin.isEmpty ? PinyinConverter.convert(card.chinese) : cardPinyin
        self.partOfSpeech = card.notes ?? ""
    }
}

// MARK: - Store

/// Persists practice-round history (capped) and the tone-confusion matrix,
/// and builds the question pools the three drill views share.
@Observable
@MainActor
final class PracticeStore {

    static let shared = PracticeStore()

    /// Finished rounds, oldest first, capped at `maxStoredResults`.
    private(set) var results: [PracticeSessionResult] = []

    /// Tone-confusion matrix keyed "expected-chosen" (e.g. "2-3" = a 2nd tone
    /// heard as a 3rd). Includes the diagonal so accuracy per tone is derivable.
    private(set) var toneConfusion: [String: Int] = [:]

    private let resultsKey = "practiceSessions"
    private let confusionKey = "toneConfusion"
    private let maxStoredResults = 200

    private init() {
        if let decoded = PersistentCodableStore.load([PracticeSessionResult].self, key: resultsKey) {
            results = decoded
        }
        if let decoded = PersistentCodableStore.load([String: Int].self, key: confusionKey) {
            toneConfusion = decoded
        }
    }

    // MARK: Round results

    /// Append a finished round, trimming the oldest entries past the cap.
    func record(_ result: PracticeSessionResult) {
        results.append(result)
        if results.count > maxStoredResults {
            results.removeFirst(results.count - maxStoredResults)
        }
        PersistentCodableStore.save(results, key: resultsKey)
    }

    /// The strongest round for a mode: highest fraction correct, ties broken
    /// by the longer round, then by recency.
    func bestScore(mode: PracticeMode) -> PracticeSessionResult? {
        results
            .filter { $0.mode == mode && $0.total > 0 }
            .max { lhs, rhs in
                if lhs.ratio != rhs.ratio { return lhs.ratio < rhs.ratio }
                if lhs.total != rhs.total { return lhs.total < rhs.total }
                return lhs.date < rhs.date
            }
    }

    /// The most recently recorded round for a mode.
    func lastResult(mode: PracticeMode) -> PracticeSessionResult? {
        results.last { $0.mode == mode }
    }

    // MARK: Tone confusion

    /// Record one syllable's answer in the tone drill. Correct answers land on
    /// the matrix diagonal; mistakes feed the "most confused pair" insight.
    func recordToneAnswer(expected: Int, chosen: Int) {
        toneConfusion["\(expected)-\(chosen)", default: 0] += 1
        PersistentCodableStore.save(toneConfusion, key: confusionKey)
    }

    /// The most frequent off-diagonal confusion cell (expected ≠ chosen),
    /// or nil when the user has never picked a wrong tone.
    var mostConfusedTonePair: (expected: Int, chosen: Int, count: Int)? {
        var best: (expected: Int, chosen: Int, count: Int)?
        for (key, count) in toneConfusion where count > 0 {
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let expected = Int(parts[0]),
                  let chosen = Int(parts[1]),
                  expected != chosen else { continue }
            // Deterministic tie-break so the insight line doesn't flicker
            // between renders when two cells share a count.
            if let current = best {
                if count > current.count ||
                    (count == current.count && (expected, chosen) < (current.expected, current.chosen)) {
                    best = (expected, chosen, count)
                }
            } else {
                best = (expected, chosen, count)
            }
        }
        return best
    }

    // MARK: Tone parsing helpers

    /// Tone number (1–5) of a single pinyin syllable, read from its diacritic
    /// (āēīōūǖ=1, áéíóúǘ=2, ǎěǐǒǔǚ=3, àèìòùǜ=4, none=5). Delegates to
    /// `PinyinConverter`'s diacritic tables rather than duplicating them.
    static func toneNumber(fromPinyinSyllable syllable: String) -> Int {
        PinyinConverter.detectTone(syllable).rawValue
    }

    /// Per-syllable tone numbers for a whole tone-marked pinyin string
    /// ("nǐ hǎo" → [3, 3]). Whitespace tokens are dropped.
    static func tonePattern(fromPinyin pinyin: String) -> [Int] {
        PinyinConverter.segment(pinyin)
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.tone.rawValue }
    }

    // MARK: Question pools

    /// Minimum saved terms before the quiz/dictation pool stands on its own.
    static let minimumVocabularyForSoloPool = 4

    /// Quizzable items from the user's saved vocabulary (entries with both
    /// language sides present).
    static func vocabularyItems() -> [PracticeItem] {
        SavedTermsStore.shared.terms.compactMap(PracticeItem.init(term:))
    }

    /// The quiz/dictation pool: the user's vocabulary, supplemented by the
    /// built-in starter deck while the vocabulary has fewer than
    /// `minimumVocabularyForSoloPool` quizzable entries (a 4-option quiz
    /// needs at least 4 distinct answers to sample from).
    static func practicePool() -> [PracticeItem] {
        let vocab = vocabularyItems()
        guard vocab.count < minimumVocabularyForSoloPool else { return vocab }
        return vocab + builtinItems(excluding: vocab)
    }

    /// A tone-drill candidate is a two-character Chinese entry whose pinyin has
    /// a tone diacritic on BOTH syllables (neutral-tone syllables carry no
    /// mark, so e.g. 谢谢 "xiè xie" is skipped).
    private static func toneDrillCandidates(from items: [PracticeItem]) -> [PracticeItem] {
        items.filter { item in
            guard item.chinese.count == 2,
                  item.chinese.allSatisfy(\.isChineseCharacter) else { return false }
            let tones = tonePattern(fromPinyin: item.pinyin)
            return tones.count == 2 && tones.allSatisfy { (1...4).contains($0) }
        }
    }

    /// Tone-drill candidates, drawn from the user's own saved vocabulary. The
    /// starter deck is only mixed in when the vocabulary yields too few
    /// two-character words to make a varied round — so a learner with a real
    /// word list drills their own words, not a fixed built-in set.
    static func toneDrillPool() -> [PracticeItem] {
        let vocabCandidates = toneDrillCandidates(from: vocabularyItems())
        guard vocabCandidates.count < minimumVocabularyForSoloPool else { return vocabCandidates }
        let vocab = vocabularyItems()
        return toneDrillCandidates(from: vocab + builtinItems(excluding: vocab))
    }

    /// Starter-deck items minus any whose Chinese side duplicates a saved
    /// term (the saved copy wins so progress reflects the user's own list).
    private static func builtinItems(excluding vocab: [PracticeItem]) -> [PracticeItem] {
        let vocabChinese = Set(vocab.map(\.chinese))
        return LearningDeck.cards
            .map(PracticeItem.init(card:))
            .filter { !vocabChinese.contains($0.chinese) }
    }
}

// MARK: - Haptics

/// Answer-feedback haptics shared by the practice drills (iOS only; macOS
/// has no haptic engine worth abstracting here).
enum PracticeHaptics {
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func error() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
