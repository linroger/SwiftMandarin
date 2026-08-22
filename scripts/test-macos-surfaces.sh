#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
binary_path="${TMPDIR:-/tmp}/swiftmandarin-macos-surface-checks"

# The opt-in flag leaves the external runner inert when Xcode compiles it as an
# app source (it does — see the synchronized `scripts` group). The runner needs
# no app sources at all: it asserts the *system* colors `SMTheme` is built on,
# which is where the bug lived.
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}" \
    xcrun swiftc \
    "$repo_root/scripts/macos-surface-checks/MacOSSurfaceChecksRunner.swift" \
    -D MACOS_SURFACE_CHECKS \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -parse-as-library \
    -o "$binary_path"

"$binary_path"

# The runner asserts the colors; these assert that the app still *uses* those
# colors. Both halves are needed: the pairing is only correct as long as the
# source and the check agree on what it is.
count_matches() {
    local pattern="$1"
    shift
    { rg -o -- "$pattern" "$@" || true; } | wc -l | tr -d ' '
}

design_system="$repo_root/SwiftMandarin/Views/Components/DesignSystem.swift"
stats_view="$repo_root/SwiftMandarin/Views/StatsView.swift"

# The page and the card must keep picking *different* system colors per
# appearance. Collapsing either back to a single color is the original bug.
page_pairing=$(count_matches 'smIsDark \? \.windowBackgroundColor : \.underPageBackgroundColor' "$design_system")
[[ "$page_pairing" == "1" ]] || {
    print -u2 "SMTheme.pageBackground no longer picks a per-appearance system color; found $page_pairing of 1"
    exit 1
}

card_pairing=$(count_matches 'smIsDark \? \.underPageBackgroundColor : \.controlBackgroundColor' "$design_system")
[[ "$card_pairing" == "1" ]] || {
    print -u2 "SMTheme.cardFill no longer picks a per-appearance system color; found $card_pairing of 1"
    exit 1
}

# `name == .darkAqua` would classify the high-contrast dark appearance as
# light and hand it the light-mode pairing — a white card on a black page.
dark_test=$(count_matches 'bestMatch\(from: \[\.aqua, \.darkAqua\]\) == \.darkAqua' "$design_system")
[[ "$dark_test" == "1" ]] || {
    print -u2 "The dark-appearance test no longer covers every dark variant; found $dark_test of 1"
    exit 1
}

# SwiftUI's `.background` ShapeStyle resolves to the window background on
# macOS, so filling a rounded rect with it paints a card in exactly the page
# color. That is how the Statistics cards became invisible.
window_colored_cards=$(count_matches '\.background\(\.background, in: Rounded' "$repo_root/SwiftMandarin")
[[ "$window_colored_cards" == "0" ]] || {
    print -u2 "A card is filled with the window background again ($window_colored_cards site(s)); use .smCardSurface()"
    { rg -n '\.background\(\.background, in: Rounded' "$repo_root/SwiftMandarin" || true; } | head -5
    exit 1
}

# Statistics is the screen that had hand-rolled surfaces; it must stay on the
# shared ones so a future fix to the palette reaches it too.
stats_page=$(count_matches 'background\(SMTheme\.pageBackground\)' "$stats_view")
[[ "$stats_page" == "1" ]] || {
    print -u2 "Statistics no longer uses the shared page background; found $stats_page of 1"
    exit 1
}

stats_cards=$(count_matches 'smCardSurface\(' "$stats_view")
[[ "$stats_cards" == "5" ]] || {
    print -u2 "Statistics no longer uses the shared card surface for all 5 panels; found $stats_cards"
    exit 1
}

print "macOS surface wiring checks passed (6/6)"
