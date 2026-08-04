#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
binary_path="${TMPDIR:-/tmp}/swiftmandarin-learning-direction-checks"

# The opt-in flag leaves the external runner inert if Xcode ever sees it as an
# app source. It also compiles out `LearningContext.current`, the one accessor
# that reaches into app state, so the mirror logic can be checked on its own.
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}" \
    xcrun swiftc \
    "$repo_root/SwiftMandarin/Models/LearningContext.swift" \
    "$repo_root/scripts/learning-direction-checks/LearningDirectionChecksRunner.swift" \
    -D LEARNING_DIRECTION_CHECKS \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -parse-as-library \
    -o "$binary_path"

"$binary_path"

# Reversal is only real if the app actually asks. These greps fail loudly when a
# surface that must mirror stops consulting the learning direction — the exact
# regression that leaves the reverse mode half-applied.
count_matches() {
    local pattern="$1"
    shift
    { rg -o -- "$pattern" "$@" || true; } | wc -l | tr -d ' '
}

# The vocabulary list must size and order the row by the studied language, and
# must offer the English pronunciation where pinyin does not apply.
vocab_headword=$(count_matches 'renderedHeadwordFontSize' "$repo_root/SwiftMandarin/Views/VocabularyView.swift")
vocab_phonetic=$(count_matches 'term\.showsPhonetic' "$repo_root/SwiftMandarin/Views/VocabularyView.swift")
[[ "$vocab_headword" -ge 2 ]] || {
    print -u2 "The vocabulary row no longer sizes the headword by its language; found $vocab_headword"
    exit 1
}
[[ "$vocab_phonetic" -ge 3 ]] || {
    print -u2 "The vocabulary list/detail views no longer show an English pronunciation; found $vocab_phonetic"
    exit 1
}

# The tappable reader must follow the learner, not the content.
translate_reader=$(count_matches 'interactiveReaderIsChinese' "$repo_root/SwiftMandarin/Views/TranslateView.swift")
translate_english_ruby=$(count_matches 'EnglishRubyTextView\(' "$repo_root/SwiftMandarin/Views/TranslateView.swift")
[[ "$translate_reader" -ge 4 ]] || {
    print -u2 "Translate no longer picks its interactive pane by learning direction; found $translate_reader"
    exit 1
}
[[ "$translate_english_ruby" == "1" ]] || {
    print -u2 "Translate no longer offers the English word-by-word reader; found $translate_english_ruby"
    exit 1
}

# Pinyin ruby is scaffolding for a Mandarin learner only.
ruby_gate=$(count_matches 'showPinyin && localization\.learningIsChinese' "$repo_root/SwiftMandarin/Views/Components/RubyTextView.swift")
[[ "$ruby_gate" == "1" ]] || {
    print -u2 "Pinyin ruby is no longer gated on the learning direction; found $ruby_gate"
    exit 1
}

# A first launch must open on the direction the learner mode implies.
persisted_default=$(count_matches '(TranslationDirection)?\.persistedDefault' \
    "$repo_root/SwiftMandarin/Views/TranslateView.swift" \
    "$repo_root/SwiftMandarin/Views/MoreView.swift" \
    "$repo_root/SwiftMandarin/Views/MacOSSettingsView.swift" \
    "$repo_root/SwiftMandarin/Models/TranslationState.swift")
[[ "$persisted_default" == "4" ]] || {
    print -u2 "A reader of the default direction still hard-codes English→Chinese; found $persisted_default of 4"
    exit 1
}

# Switching the interface language re-classes `Bundle.main` so its ObjC
# `localizedString(forKey:value:table:)` resolves against the chosen `.lproj`.
# SwiftUI's `Text("…")` goes through that method; `String(localized:)` does NOT
# — it uses Foundation's own lookup and silently follows the DEVICE language.
# Every assembled string must therefore name the bundle explicitly, or half the
# interface stays in the wrong language with no compiler complaint.
# `grep -v` exits non-zero when it filters every line away, which under
# `pipefail` would abort the script exactly when the check is passing — so the
# scan is wrapped to always succeed and judged on its output instead.
unrouted_sites() {
    { rg -n --glob '!**/LocalizationManager.swift' --glob '!**/LanguageBundleOverride.swift' \
        'String\(localized:' "$repo_root/SwiftMandarin" || true; } \
        | { grep -v 'bundle: \.appLanguage' || true; } \
        | { grep -v 'String(localized: audioPlan' || true; } \
        | { grep -vE '^[^:]+:[0-9]+:[[:space:]]*///' || true; }
}

unrouted=$(unrouted_sites | wc -l | tr -d ' ')
[[ "$unrouted" == "0" ]] || {
    print -u2 "A String(localized:) call bypasses the in-app language override ($unrouted site(s)):"
    unrouted_sites | head -5
    exit 1
}

# Foundation declares init(localized:table:bundle:locale:comment:), so a
# `comment:` written before `bundle:` is an argument-order error rather than a
# style nit — it fails the build outright.
bad_order=$({ rg -n 'comment:[^)]*bundle: \.appLanguage' "$repo_root/SwiftMandarin" || true; } | wc -l | tr -d ' ')
[[ "$bad_order" == "0" ]] || {
    print -u2 "A String(localized:) call passes comment: before bundle: ($bad_order site(s))"
    exit 1
}

print "Learning direction wiring checks passed (8/8)"
