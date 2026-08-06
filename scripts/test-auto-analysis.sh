#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
binary_path="${TMPDIR:-/tmp}/swiftmandarin-auto-analysis-checks"

# The opt-in flag leaves the external runner inert when Xcode compiles it as an
# app source (it does — see the synchronized `scripts` group). `AutoAnalysisQueue`
# itself needs no flag: it is deliberately free of app dependencies so the rules
# that bound automatic spending can be checked without a provider or a cache.
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}" \
    xcrun swiftc \
    "$repo_root/SwiftMandarin/Models/AutoAnalysisQueue.swift" \
    "$repo_root/scripts/auto-analysis-checks/AutoAnalysisQueueChecksRunner.swift" \
    -D AUTO_ANALYSIS_CHECKS \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -parse-as-library \
    -o "$binary_path"

"$binary_path"

# The queue rules only protect the user if the app actually routes through them.
# These greps fail loudly when a wire is cut — the exact regression that turns
# "analyze new words automatically" into either silence or an unbounded bill.
count_matches() {
    local pattern="$1"
    shift
    { rg -o -- "$pattern" "$@" || true; } | wc -l | tr -d ' '
}

# Same count over code only. The file documents in prose the very things some
# checks forbid in code (that it never generates audio, for one), so a plain
# grep would flag its own explanation. `grep -v` exits non-zero when it filters
# every line away, which under `pipefail` would abort exactly when the check is
# passing — so each stage is wrapped to always succeed.
count_code_matches() {
    local pattern="$1"
    shift
    { rg -n --no-filename -- "$pattern" "$@" || true; } \
        | { grep -vE '^[0-9]+:[[:space:]]*//' || true; } \
        | wc -l | tr -d ' '
}

coordinator="$repo_root/SwiftMandarin/Models/AutoAnalysisCoordinator.swift"

# Every capture surface saves through `SavedTermsStore.add`, so both overloads
# must notify the queue or whole features (Shortcuts, import, photo capture)
# would silently stop being analyzed.
store_hooks=$(count_matches 'AutoAnalysisCoordinator\.shared\.noteTermAdded' \
    "$repo_root/SwiftMandarin/Models/SavedTerm.swift")
[[ "$store_hooks" == "2" ]] || {
    print -u2 "Saving a term no longer feeds the automatic analysis queue; found $store_hooks of 2 add() overloads"
    exit 1
}

# Opt-in is the whole safety story: nothing may be queued or dispatched unless
# the user turned the feature on.
opt_in=$(count_matches 'autoAnalyzeNewTerms' "$coordinator")
[[ "$opt_in" -ge 4 ]] || {
    print -u2 "The automatic queue no longer gates on the user's opt-in; found $opt_in guards"
    exit 1
}

# Automatic analysis must never reach the paid speech pipeline: MiniMax audio is
# billed per character and the manual flow gates it behind an explicit preflight.
audio_leak=$(count_code_matches '[Aa]udio|[Ss]peech|MiniMax' "$coordinator")
[[ "$audio_leak" == "0" ]] || {
    print -u2 "The automatic queue now references audio generation ($audio_leak site(s)); it must never spend on speech"
    exit 1
}

# A reviewed batch was started deliberately and may cover the same words; the
# automatic queue yields rather than doubling the request rate.
yields_to_batch=$(count_matches 'BatchExplanationController\.shared\.isRunning' "$coordinator")
[[ "$yields_to_batch" == "1" ]] || {
    print -u2 "The automatic queue no longer yields to a running batch; found $yields_to_batch"
    exit 1
}

# A response must not be cached under settings that changed while it was in
# flight, or the cache stops being an honest record of what produced it.
stale_guard=$(count_matches 'matchesCurrentSettings\(\)' "$coordinator")
[[ "$stale_guard" == "1" ]] || {
    print -u2 "The automatic queue no longer re-verifies settings before caching; found $stale_guard"
    exit 1
}

# Repeated failures must stop the queue instead of re-billing a broken endpoint
# once per saved word.
failure_pause=$(count_matches 'failurePauseThreshold' "$coordinator")
[[ "$failure_pause" -ge 2 ]] || {
    print -u2 "The automatic queue no longer pauses after repeated failures; found $failure_pause"
    exit 1
}

# Work interrupted by quitting the app is recovered on the next launch.
resume=$(count_matches 'AutoAnalysisCoordinator\.shared\.resumePendingWork' \
    "$repo_root/SwiftMandarin/ContentView.swift")
[[ "$resume" == "1" ]] || {
    print -u2 "Launch no longer resumes an interrupted automatic queue; found $resume"
    exit 1
}

# The toggle has to be reachable, and its state visible, from the batch screen.
toggle=$(count_matches 'settings\.autoAnalyzeNewTerms' \
    "$repo_root/SwiftMandarin/Views/Components/BatchAIAnalysisView.swift")
[[ "$toggle" -ge 3 ]] || {
    print -u2 "The batch screen no longer exposes the automatic-analysis toggle; found $toggle"
    exit 1
}

# The feature is bilingual like the rest of the app: every string it introduced
# must carry a translation, or the 中文 interface reverts to English exactly on
# the screen that explains what the app is spending tokens on.
python3 - "$repo_root/SwiftMandarin/Localizable.xcstrings" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    strings = json.load(handle)["strings"]

required = [
    "Auto-Translate New Words",
    "Automatic Analysis",
    "Queued",
    "Analyzed Automatically",
    "Analyzing %@…",
    "Last analyzed: %@",
    "Waiting for an AI provider. Configure one in Settings → AI.",
    "Waiting for the reviewed batch run to finish.",
    "Paused after repeated failures.",
    "Resume Automatic Analysis",
    "Clear Automatic Queue",
    "%lld words were not queued because the queue was full. Run the batch below to analyze them.",
    "Automatic analysis queue",
    "%lld words waiting",
    "AI or language settings changed while a word was being analyzed automatically. The response was discarded and the word was queued again.",
]

missing = []
for key in required:
    unit = (
        strings.get(key, {})
        .get("localizations", {})
        .get("zh-Hans", {})
        .get("stringUnit", {})
    )
    if unit.get("state") != "translated" or not unit.get("value"):
        missing.append(key)

if missing:
    sys.stderr.write(
        "Automatic-analysis strings are missing a zh-Hans translation (%d):\n" % len(missing)
    )
    for key in missing[:5]:
        sys.stderr.write("  %r\n" % key)
    sys.exit(1)
PY

print "Auto-analysis wiring checks passed (9/9)"
