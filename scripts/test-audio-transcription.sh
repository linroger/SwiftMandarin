#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
service="$repo_root/SwiftMandarin/Services/AudioTranscriptionService.swift"
settings="$repo_root/SwiftMandarin/Models/AIModelSettings.swift"
pane="$repo_root/SwiftMandarin/Views/Components/MultimodalAudioInputView.swift"

# File transcription is orchestration of two Apple engines plus a provider
# choice — there is no pure logic to extract, so these are wiring guards. Each
# one states a defect that actually shipped, so removing the fix fails loudly
# instead of silently restoring "record and transcribe does nothing".
count_matches() {
    local pattern="$1"
    shift
    { rg -o -- "$pattern" "$@" || true; } | wc -l | tr -d ' '
}

# On iOS 26/macOS 26 an uninstalled locale has no working recognizer of either
# kind. Live dictation always installed its model; file transcription did not,
# which is exactly why one worked and the other failed on the same device.
asset_install=$(count_matches 'AssetInventory' "$service")
[[ "$asset_install" -ge 2 ]] || {
    print -u2 "File transcription no longer installs the on-device speech model; found $asset_install AssetInventory references"
    exit 1
}

# The analyzer must be the primary engine where it exists — it is the only one
# whose model the app can install.
analyzer=$(count_matches 'SpeechAnalyzer|SpeechTranscriber' "$service")
[[ "$analyzer" -ge 3 ]] || {
    print -u2 "File transcription no longer uses the modern speech analyzer; found $analyzer references"
    exit 1
}

# The legacy recognizer stays as the fallback for older iOS and unsupported
# locales; losing it would strand every release below 26.
legacy=$(count_matches 'SFSpeechURLRecognitionRequest\(url:' "$service")
[[ "$legacy" == "1" ]] || {
    print -u2 "The legacy URL recognizer fallback is gone; found $legacy"
    exit 1
}

# A stalled on-device pass used to burn the full two-minute timeout before the
# server retry, which reads as a hang rather than a fallback.
short_deadline=$(count_matches 'onDeviceRecognitionTimeout' "$service")
[[ "$short_deadline" -ge 2 ]] || {
    print -u2 "The on-device pass no longer has its own shorter deadline; found $short_deadline"
    exit 1
}

# Audio routing is a privacy decision. The user's selected provider must be
# honored rather than filtered away, or a recording silently uploads to a
# different account that merely happens to have a key.
honors_selection=$(count_matches 'effective\.isCloud, isAvailable\(effective\)' "$settings")
[[ "$honors_selection" == "1" ]] || {
    print -u2 "AI transcription no longer honors the selected provider; found $honors_selection"
    exit 1
}

# ...and the pane has to say where the audio goes, in words.
names_provider=$(count_matches 'Audio is sent to' "$pane")
[[ "$names_provider" == "1" ]] || {
    print -u2 "The audio pane no longer names the provider the recording is sent to; found $names_provider"
    exit 1
}

# A first-run model download can take minutes; without progress the pane looks
# hung on exactly the run doing the most work.
download_progress=$(count_matches 'modelDownloadProgress' "$service" "$pane")
[[ "$download_progress" -ge 4 ]] || {
    print -u2 "Speech-model download progress is no longer surfaced; found $download_progress references"
    exit 1
}

# Every string this feature introduced must carry a translation, or the 中文
# interface reverts to English on the screen explaining where audio is sent.
python3 - "$repo_root/SwiftMandarin/Localizable.xcstrings" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    strings = json.load(handle)["strings"]

required = [
    "The on-device speech model for %@ could not be downloaded: %@. Check your network connection and try again, or switch to an AI transcription provider.",
    "AI transcription needs a cloud provider. Add an API key in Settings → AI, or switch back to Apple Speech.",
    "Audio is sent to %@.",
    "Downloading the %@ speech model…",
    "Speech model download",
    "speech-to-text model id",
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
    sys.stderr.write("Transcription strings are missing a zh-Hans translation (%d):\n" % len(missing))
    for key in missing[:5]:
        sys.stderr.write("  %r\n" % key)
    sys.exit(1)
PY

print "Audio transcription wiring checks passed (8/8)"
