//
//  LearningContext.swift
//  SwiftMandarin
//
//  One place to answer the questions every bilingual surface keeps asking:
//  which side of an English/Chinese pair is the learner studying, which side
//  do they already read, and which learner aids (pinyin, tone colors, the
//  tappable ruby reader) are meaningful at all.
//
//  Why this exists
//  ---------------
//  The app is a mirror: an English speaker learning Mandarin and a Mandarin
//  speaker learning English get the same features with the two languages
//  swapped. Before this type, that swap was re-derived inline at every call
//  site from `LocalizationManager.shared.learningIsChinese`, which made it
//  easy to reverse the *text* while forgetting the *pinyin affordance* or the
//  *word-by-word reader* that goes with it. Deriving them all from one value
//  keeps the two directions genuinely symmetric.
//
//  The core is a pure, `Sendable`, Foundation-only value so the mirror
//  property — "every accessor of the reversed context equals the swapped
//  accessor of the forward one" — can be asserted by the standalone contract
//  runner in `scripts/learning-direction-checks/` without a UI, a bundle, or
//  a main actor.
//

import Foundation

// MARK: - Learning Context (pure)

/// The resolved language roles for one learner. `learningIsChinese` is the
/// only stored fact; everything else is that fact projected onto a specific
/// question a view or model needs answered.
nonisolated struct LearningContext: Equatable, Sendable {

    /// Whether Mandarin is the language being *studied*. When false the user
    /// is a Mandarin speaker studying English and every pair is reversed.
    let learningIsChinese: Bool

    init(learningIsChinese: Bool) {
        self.learningIsChinese = learningIsChinese
    }

    /// The user's native language is always the other one.
    var nativeIsChinese: Bool { !learningIsChinese }

    /// The same learner with the two languages swapped. Used by the contract
    /// checks to assert the two directions really are mirror images.
    var mirrored: LearningContext {
        LearningContext(learningIsChinese: !learningIsChinese)
    }

    // MARK: Text selection

    /// The side shown big — the language being studied.
    func primary(chinese: String, english: String) -> String {
        learningIsChinese ? chinese : english
    }

    /// The side shown small — the language the user already reads.
    func secondary(chinese: String, english: String) -> String {
        learningIsChinese ? english : chinese
    }

    // MARK: Learner aids

    /// Pinyin, tone marks, tone colors, and tone drills teach the *reading* of
    /// Chinese. They are learner scaffolding, so they belong only to the
    /// learner who is decoding Chinese — a native Mandarin reader studying
    /// English needs none of them on their own language.
    var showsPinyinAffordances: Bool { learningIsChinese }

    /// Whether the tappable word-by-word reader should segment Chinese
    /// (`RubyTextView`) rather than English (`EnglishRubyTextView`).
    var interactiveReaderIsChinese: Bool { learningIsChinese }
}

// MARK: - Live resolution

// This is the only part of the file that touches app state. It is compiled out
// of the standalone contract runner (which defines `LEARNING_DIRECTION_CHECKS`)
// so the pure mirror logic above can be verified without dragging in
// `LocalizationManager` and everything it depends on. Xcode never defines that
// flag, so the app always gets this extension.
#if !LEARNING_DIRECTION_CHECKS
extension LearningContext {

    /// The context implied by the current interface language. The interface
    /// language *is* the user's native language (see `LocalizationManager`),
    /// so one read answers the whole question.
    @MainActor
    static var current: LearningContext {
        LearningContext(learningIsChinese: LocalizationManager.shared.learningIsChinese)
    }
}
#endif
