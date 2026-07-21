#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
coordinator="$repo_root/SwiftMandarin/Services/AudioSessionCoordinator.swift"
binary_path="${TMPDIR:-/tmp}/swiftmandarin-audio-session-transition-checks"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

service_files=(
    "$repo_root/SwiftMandarin/Services/SpeechService.swift"
    "$repo_root/SwiftMandarin/Services/AudioCaptureService.swift"
    "$repo_root/SwiftMandarin/Services/SpeechRecognitionService.swift"
)

for service_file in "${service_files[@]}"; do
    if rg -n '\.setActive[[:space:]]*\(' "$service_file" >/dev/null; then
        echo "Direct AVAudioSession.setActive call escaped into $service_file" >&2
        exit 1
    fi
done

while IFS= read -r source_file; do
    [[ -z "$source_file" ]] && continue
    if [[ "$source_file" != "$coordinator" ]]; then
        echo "Direct AVAudioSession.setActive is outside the legacy coordinator fallback: $source_file" >&2
        exit 1
    fi
done < <(rg -l '\.setActive[[:space:]]*\(' "$repo_root/SwiftMandarin" -g '*.swift' || true)

set_active_count=$(rg -n '\.setActive[[:space:]]*\(' "$coordinator" | wc -l | tr -d ' ')
if [[ "$set_active_count" != "2" ]]; then
    echo "Expected exactly two legacy setActive fallbacks; found $set_active_count" >&2
    exit 1
fi

rg -Fq 'if #available(iOS 27.0, *) {' "$coordinator"
rg -Fq 'let activated = try await session.activate(options: [])' "$coordinator"
rg -Fq 'let deactivated = try await session.deactivate(' "$coordinator"
rg -Fq 'AudioSessionTransitionError.activationReturnedFalse' "$coordinator"
rg -Fq 'AudioSessionTransitionError.deactivationReturnedFalse' "$coordinator"

DEVELOPER_DIR="$developer_dir" xcrun swiftc \
    "$coordinator" \
    "$repo_root/scripts/audio-session-checks/AudioSessionTransitionChecksRunner.swift" \
    -D AUDIO_SESSION_CHECKS \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -parse-as-library \
    -o "$binary_path"

"$binary_path"

# Type-check against the iOS 27 SDK with the app's iOS 17 deployment floor.
# This validates both the new activate/deactivate spellings and the guarded
# compatibility fallback without needing a simulator runtime or microphone.
ios_sdk=$(DEVELOPER_DIR="$developer_dir" xcrun --sdk iphonesimulator --show-sdk-path)
DEVELOPER_DIR="$developer_dir" xcrun swiftc \
    "$coordinator" \
    -D AUDIO_SESSION_CHECKS \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -parse-as-library \
    -typecheck \
    -sdk "$ios_sdk" \
    -target arm64-apple-ios17.0-simulator

echo "Audio-session source and iOS 27 API checks passed."
