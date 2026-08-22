#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
binary_path="${TMPDIR:-/tmp}/swiftmandarin-stats-heatmap-checks"

# The opt-in flag leaves the external runner inert when Xcode compiles it as an
# app source (it does — see the synchronized `scripts` group). `LearningActivity`
# needs only the persistence helper and the language-bundle shim, so the day-by-day
# mastery arithmetic can be checked without standing up the rest of the app.
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}" \
    xcrun swiftc \
    "$repo_root/SwiftMandarin/Models/LearningActivity.swift" \
    "$repo_root/SwiftMandarin/Models/PersistentCodableStore.swift" \
    "$repo_root/SwiftMandarin/Models/LanguageBundleOverride.swift" \
    "$repo_root/scripts/stats-heatmap-checks/StatsHeatmapChecksRunner.swift" \
    -D STATS_HEATMAP_CHECKS \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -parse-as-library \
    -o "$binary_path"

"$binary_path"

# The arithmetic above only matters if the app still feeds it. These greps fail
# loudly when a wire is cut — the regression that leaves the heatmap counting
# mastery that no longer happens, or double-counting mastery that does.
count_matches() {
    local pattern="$1"
    shift
    { rg -o -- "$pattern" "$@" || true; } | wc -l | tr -d ' '
}

saved_term="$repo_root/SwiftMandarin/Models/SavedTerm.swift"
stats_view="$repo_root/SwiftMandarin/Views/StatsView.swift"

# Mastery is reachable from a swipe action, a context menu and two detail
# toggles. All of them go through the store's two entry points, and both of
# those must funnel into the one place that records the milestone — otherwise
# a word mastered from the "wrong" surface never reaches the heatmap.
funnel=$(count_matches 'applyMastered\(' "$saved_term")
[[ "$funnel" == "3" ]] || {
    print -u2 "Mastery no longer funnels through a single recorded transition; found $funnel of 3 (its declaration plus the toggle and set entry points)"
    exit 1
}

record=$(count_matches 'LearningActivityStore\.shared\.recordWordMastered' "$saved_term")
[[ "$record" == "1" ]] || {
    print -u2 "Marking a term mastered no longer credits the activity heatmap; found $record of 1"
    exit 1
}

undo=$(count_matches 'LearningActivityStore\.shared\.undoWordMastered' "$saved_term")
[[ "$undo" == "1" ]] || {
    print -u2 "Un-mastering a term no longer refunds its milestone; found $undo of 1"
    exit 1
}

# `applyMastered` short-circuits when the flag is already what the caller asked
# for. Without that guard a redundant `setMastered(term, isMastered: true)` —
# which the detail toggles can produce — awards the same word twice.
idempotent=$(count_matches 'guard terms\[index\]\.isMastered != isMastered else \{ return \}' "$saved_term")
[[ "$idempotent" == "1" ]] || {
    print -u2 "Mastery transitions are no longer idempotent; a repeat call would double-count. Found $idempotent"
    exit 1
}

# Editing a term rebuilds it field by field, so `update` has to carry the
# mastery bookkeeping over itself. Losing `dateMastered` there would strand the
# milestone: the word stays mastered but its day can never be refunded.
preserved=$(count_matches 'replacement\.dateMastered = terms\[index\]\.dateMastered' "$saved_term")
[[ "$preserved" == "1" ]] || {
    print -u2 "Editing a term no longer preserves when it was mastered; found $preserved of 1"
    exit 1
}

# The count is only useful if the user can see it: tapping a heatmap cell must
# break the day down by mastery alongside the other metrics.
shown=$(count_matches 'activity\.wordsMastered' "$stats_view")
[[ "$shown" == "1" ]] || {
    print -u2 "The selected-day breakdown no longer shows words mastered; found $shown of 1"
    exit 1
}

# The Words Learned chart offers three ranges, and the widest one must thin its
# axis labels or 30 days of dates overlap into an unreadable smear.
range_days=$(count_matches 'case \.month: return 30' "$stats_view")
[[ "$range_days" == "1" ]] || {
    print -u2 "The Words Learned chart no longer offers a 30-day range; found $range_days"
    exit 1
}

axis_stride=$(count_matches 'barChartTimeRange\.axisLabelStride' "$stats_view")
[[ "$axis_stride" == "1" ]] || {
    print -u2 "The Words Learned x-axis no longer thins its labels for the wider ranges; found $axis_stride"
    exit 1
}

# Both new surfaces are bilingual like the rest of the app. The day-breakdown
# metrics are icon-only on screen, so these keys are what a screen reader
# announces — untranslated, the 中文 interface reads them out in English.
python3 - "$repo_root/SwiftMandarin/Localizable.xcstrings" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    strings = json.load(handle)["strings"]

required = [
    "30 Days",
    "Words Learned",
    "Words Mastered",
    "Reviews",
    "Translations",
    "Questions Graded",
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
        "Heatmap/chart strings are missing a zh-Hans translation (%d):\n" % len(missing)
    )
    for key in missing:
        sys.stderr.write("  %r\n" % key)
    sys.exit(1)
PY

print "Stats heatmap wiring checks passed (8/8)"
