#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
binary_path="${TMPDIR:-/tmp}/swiftmandarin-minimax-audio-contract-checks"

# This runner compiles the production cache, decoder, and persistence sources
# but only invokes their pure/offline entry points. It does not access Keychain,
# construct an API credential, or call MiniMax (or any other network service).
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}" \
    xcrun swiftc \
    "$repo_root/SwiftMandarin/Models/MiniMaxAudioModels.swift" \
    "$repo_root/SwiftMandarin/Services/MiniMaxAudioClient.swift" \
    "$repo_root/SwiftMandarin/Services/GeneratedSpeechStore.swift" \
    "$repo_root/scripts/minimax-audio-checks/MiniMaxAudioContractChecksRunner.swift" \
    -D MINIMAX_AUDIO_CHECKS \
    -parse-as-library \
    -o "$binary_path"

"$binary_path"
