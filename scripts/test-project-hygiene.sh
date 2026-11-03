#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
pbxproj="$repo_root/SwiftMandarin.xcodeproj/project.pbxproj"

# Guards for the plumbing that every other check depends on. Each states a
# defect that actually shipped: a project file that re-listed every source and
# drowned real compiler warnings in 220 "duplicate build file" lines, check
# scripts pinned to an Xcode that was later deleted, and two main-thread stalls
# that read as "the app hangs".
count_matches() {
    local pattern="$1"
    shift
    { rg -o -- "$pattern" "$@" || true; } | wc -l | tr -d ' '
}

# `SwiftMandarin/` is a file-system-synchronized group, so every source under
# it is already in the target. Explicit `PBXBuildFile` entries for those files
# are duplicates; Xcode skips them with a warning per file per build, and that
# noise is where real warnings went to hide.
duplicate_sources=$(count_matches ' in Sources \*/' "$pbxproj")
[[ "$duplicate_sources" == "0" ]] || {
    print -u2 "The project file lists $duplicate_sources explicit source build files again; the synchronized group already owns them"
    exit 1
}

# Agent session logs and scratch memory are not project content and must not
# be referenced from the project (they were, by the dozen).
junk_refs=$(count_matches 'path = "?(logs|\.remember|\.claude)/' "$pbxproj")
[[ "$junk_refs" == "0" ]] || {
    print -u2 "The project file references $junk_refs session-log or scratch files"
    exit 1
}

# The toolchain is whatever `xcode-select` points at; a hard-coded Xcode path
# stops the whole suite the day that Xcode is removed.
pinned_xcode=$(count_matches 'Xcode-beta\.app' "$repo_root"/scripts/*.sh "$repo_root/init.sh")
[[ "$pinned_xcode" == "0" ]] || {
    print -u2 "$pinned_xcode script(s) still pin a specific Xcode install instead of xcode-select"
    exit 1
}

# Store persistence must stay coalesced and off the main thread — an import of
# N words used to re-encode the whole vocabulary N times synchronously — and
# whatever is pending must be flushed when the app resigns active or exits.
# The write leaves the main thread on a serial queue (`writeQueue.async`) so
# batches land in order; the earlier `Task.detached` marker is accepted too.
store="$repo_root/SwiftMandarin/Models/PersistentCodableStore.swift"
coalesced=$(count_matches 'pendingWrites\[key\]|Task\.detached|writeQueue\.async' "$store")
[[ "$coalesced" -ge 2 ]] || {
    print -u2 "PersistentCodableStore.save no longer coalesces writes off the main thread; found $coalesced markers"
    exit 1
}
flushes=$(count_matches 'PersistentCodableStore\.flushPendingWritesNow\(\)' "$repo_root/SwiftMandarin/SwiftMandarinApp.swift")
[[ "$flushes" -ge 2 ]] || {
    print -u2 "The app no longer flushes pending store writes on scene-phase change and termination; found $flushes call(s) of 2"
    exit 1
}

# The vocabulary list filters and sorts once per update; reading the computed
# property at every site in `body` multiplied the cost by the number of sites.
once=$(count_matches 'let visibleTerms = filteredTerms' "$repo_root/SwiftMandarin/Views/VocabularyView.swift")
[[ "$once" == "1" ]] || {
    print -u2 "VocabularyView no longer computes its filtered list once per update; found $once"
    exit 1
}
keyed_sort=$(count_matches 'key: \$0\.headlineText' "$repo_root/SwiftMandarin/Views/VocabularyView.swift")
[[ "$keyed_sort" == "1" ]] || {
    print -u2 "VocabularyView's alphabetical sort no longer precomputes headwords; found $keyed_sort"
    exit 1
}

# The Study hub (iOS) and the sidebar's detail column (macOS) own the
# navigation stack. A screen pushed into them that brought its own stack
# nested two stacks and doubled the navigation bar. `rg` matches one line at a
# time, so a pattern spanning `body {` and the next line never fired; and
# `rg -U` also matches the sheets in these files, which rightly own a stack.
# So check only each hub struct's own body: its first line that is neither
# blank nor a comment. A hub whose body is not found fails too, so a rename
# cannot turn this guard back into one that always passes.
views="$repo_root/SwiftMandarin/Views"
own_stacks=0
for hub in LearnView PracticeHubView ConversationView ReaderView; do
    n=$(awk -v name="$hub" '
        $0 ~ "struct " name "(<[^>]*>)?: View \\{" { inhub = 1; next }
        inhub && /var body: some View \{/            { want = 1; next }
        want && !/^[[:space:]]*(\/\/.*)?$/          { checked = 1; if ($0 ~ /^[[:space:]]*NavigationStack/) n++; exit }
        END { print (checked ? n + 0 : "missing") }' "$views/$hub.swift")
    [[ "$n" != "missing" ]] || {
        print -u2 "Could not find the body of $hub in $views/$hub.swift to check it for its own NavigationStack"
        exit 1
    }
    # An assignment, not `(( own_stacks += n ))`: under `set -e` an
    # arithmetic command that evaluates to 0 is a failure and ends the script.
    own_stacks=$(( own_stacks + n ))
done
[[ "$own_stacks" == "0" ]] || {
    print -u2 "$own_stacks hub screen(s) wrap their body in their own NavigationStack again"
    exit 1
}
hosted=$(count_matches 'hosted \{' "$repo_root/SwiftMandarin/ContentView.swift")
[[ "$hosted" -ge 5 ]] || {
    print -u2 "The macOS detail column no longer hosts the stack-less screens in a NavigationStack; found $hosted of 5"
    exit 1
}

# Global search: the iOS 26 search tab (iPad regular width only — on iPhone a
# sixth tab folds Study and More into the system overflow list, and a Plus or
# Pro Max iPhone in landscape is regular width too, so the size class alone is
# no iPhone gate), the Study Library row, the Home toolbar button, and the
# macOS sidebar item all open the same screen.
search_tab=$(count_matches 'Tab\(AppTab\.search\.titleKey, systemImage: AppTab\.search\.icon, value: AppTab\.search, role: \.search\)' "$repo_root/SwiftMandarin/ContentView.swift")
search_row=$(count_matches 'libraryRow\(\.search, route: \.search\)' "$views/StudyHubView.swift")
search_sidebar=$(count_matches '\.tag\(AppTab\.search\)' "$repo_root/SwiftMandarin/ContentView.swift")
search_home=$(count_matches 'GlobalSearchView\(selectedTab: \$selectedTab\)' "$views/HomeView.swift")
search_gated=$(count_matches 'userInterfaceIdiom == \.pad && horizontalSizeClass == \.regular' "$repo_root/SwiftMandarin/ContentView.swift")
[[ "$search_tab" == "1" && "$search_row" == "1" && "$search_sidebar" == "1" && "$search_home" == "1" && "$search_gated" -ge 1 ]] || {
    print -u2 "Global search lost an entry point or its iPhone gate (tab: $search_tab, gate: $search_gated, Study row: $search_row, Home: $search_home, sidebar: $search_sidebar)"
    exit 1
}
minimize=$(count_matches 'tabBarMinimizeOnScrollCompat\(\)' "$repo_root/SwiftMandarin/ContentView.swift")
[[ "$minimize" == "1" ]] || {
    print -u2 "The iOS tab bar no longer minimizes on scroll; found $minimize"
    exit 1
}

print "Project hygiene checks passed (11/11)"
