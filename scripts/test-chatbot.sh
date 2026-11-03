#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
binary_path="${TMPDIR:-/tmp}/swiftmandarin-chatbot-checks"

# The opt-in flag keeps this standalone runner inert if it is ever discovered
# by an Xcode source group.
DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}" \
    xcrun swiftc \
    "$repo_root/SwiftMandarin/Models/LanguageBundleOverride.swift" \
    "$repo_root/SwiftMandarin/Services/AIResponseParsing.swift" \
    "$repo_root/SwiftMandarin/Services/ChatbotPrompt.swift" \
    "$repo_root/scripts/chatbot-checks/ChatbotChecksRunner.swift" \
    -D CHATBOT_CHECKS \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -parse-as-library \
    -o "$binary_path"

"$binary_path"

count_matches() {
    local pattern="$1"
    shift
    { rg -o -- "$pattern" "$@" || true; } | wc -l | tr -d ' '
}

service="$repo_root/SwiftMandarin/Services/ChatbotService.swift"
view="$repo_root/SwiftMandarin/Views/ChatbotView.swift"

# Every provider path parses through the shared contract; none hands a raw
# completion to the chat.
parsed=$(count_matches 'ChatbotResponseParser\.parse\(' "$service")
generable=$(count_matches 'generating: ChatbotGeneratedReply\.self' "$service")
# A reply whose chunks were unusable is chunked on the device, never shown bare.
fallback=$(count_matches 'Self\.localChunks\(for:' "$service")
# The screen has no stack of its own (it is pushed or hosted), and it has an
# entry point on every platform.
own_stack=$(count_matches 'NavigationStack \{' "$view")
sidebar=$(count_matches 'toolTabs: \[AppTab\] = \[[^]]*\.chat' "$repo_root/SwiftMandarin/ContentView.swift")
sidebar_destination=$(count_matches 'hosted \{ ChatbotView\(\) \}' "$repo_root/SwiftMandarin/ContentView.swift")
hub=$(count_matches 'path\.append\(StudyRoute\.chat\)' "$repo_root/SwiftMandarin/Views/StudyHubView.swift")
hub_destination=$(count_matches 'case \.chat: ChatbotView\(\)' "$repo_root/SwiftMandarin/Views/StudyHubView.swift")
translate=$(count_matches 'ChatbotView\(\)' "$repo_root/SwiftMandarin/Views/TranslateView.swift")
deeplink=$(count_matches 'case "chat": selectedTab = \.chat' "$repo_root/SwiftMandarin/Models/AppRouteStore.swift")

[[ "$parsed" == "2" ]] || { print -u2 "Expected the Ollama and cloud paths to parse through ChatbotResponseParser; found $parsed"; exit 1 }
[[ "$generable" == "1" ]] || { print -u2 "Expected Apple Intelligence to use guided generation for chat replies; found $generable"; exit 1 }
[[ "$fallback" -ge 1 ]] || { print -u2 "Unusable chunks are no longer rebuilt on the device"; exit 1 }
# The three NavigationStacks in the view file belong to its two sheets and its
# preview; a fourth would be the screen wrapping itself again.
[[ "$own_stack" == "3" ]] || { print -u2 "Expected NavigationStacks only in the two AI Chat sheets and the preview; found $own_stack"; exit 1 }
[[ "$sidebar" == "1" && "$sidebar_destination" == "1" ]] || { print -u2 "The macOS sidebar lost its AI Chat item or destination (item: $sidebar, destination: $sidebar_destination)"; exit 1 }
[[ "$hub" == "1" && "$hub_destination" == "1" ]] || { print -u2 "The Study hub lost its AI Chat row or destination (row: $hub, destination: $hub_destination)"; exit 1 }
[[ "$translate" == "1" ]] || { print -u2 "The Translate toolbar lost its AI Chat button; found $translate"; exit 1 }
[[ "$deeplink" == "1" ]] || { print -u2 "The macOS 'chat' deep link no longer selects AI Chat; found $deeplink"; exit 1 }

print "AI Chat wiring checks passed (8/8)"
