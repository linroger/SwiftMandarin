#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
binary_path="${TMPDIR:-/tmp}/swiftmandarin-interpreter-checks"
developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
app="$repo_root/SwiftMandarin"
runner="$repo_root/scripts/interpreter-checks/InterpreterChecksRunner.swift"

# The transcript assembler is pure, and the coordinator talks only to
# protocols, so this slice compiles without the app and runs every transition,
# cancellation and failure against scripted stand-ins: no microphone, no
# language pack, no speaker. The opt-in flag keeps the runner inert if Xcode
# ever sees it as an app source.
pure_sources=(
    "$app/Models/LanguageBundleOverride.swift"
    "$app/Models/TranslationDirection.swift"
    "$app/Models/InterpreterModels.swift"
    "$app/Models/TranscriptAssembler.swift"
    "$app/Services/InterpreterPipeline.swift"
    "$app/Services/SpeechTranslationCoordinator.swift"
)

DEVELOPER_DIR="$developer_dir" xcrun swiftc \
    "${pure_sources[@]}" \
    "$runner" \
    -D INTERPRETER_CHECKS \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -parse-as-library \
    -o "$binary_path"

"$binary_path"

# The services that talk to Speech and Translation cannot run here — they
# need a microphone and installed language assets — but they are held to the
# same standard: Swift 6 language mode, complete concurrency checking and
# warnings as errors, at the app's own deployment targets. The Simulator pass
# also covers the stand-ins that only exist there, and the device pass covers
# the branches the Simulator build leaves out.
framework_sources=(
    "${pure_sources[@]}"
    "$app/Services/SpeechModelProvisioner.swift"
    "$app/Services/PushToTalkTranscriptionService.swift"
    "$app/Services/InterpreterTranslationService.swift"
    "$app/Services/InterpreterSimulatorStandIns.swift"
    "$runner"
)
strict_flags=(
    -D INTERPRETER_CHECKS
    -swift-version 6
    -strict-concurrency=complete
    -warnings-as-errors
    -parse-as-library
    -typecheck
)

DEVELOPER_DIR="$developer_dir" xcrun swiftc \
    "${framework_sources[@]}" "${strict_flags[@]}" \
    -target arm64-apple-macos26.2
DEVELOPER_DIR="$developer_dir" xcrun --sdk iphonesimulator swiftc \
    "${framework_sources[@]}" "${strict_flags[@]}" \
    -target arm64-apple-ios17.0-simulator
DEVELOPER_DIR="$developer_dir" xcrun --sdk iphoneos swiftc \
    "${framework_sources[@]}" "${strict_flags[@]}" \
    -target arm64-apple-ios17.0

print "Interpreter services type-check under Swift 6 for macOS, the iOS Simulator and iOS."

# What cannot be executed here is pinned by wiring guards. Each states a rule
# from the feature's design, so breaking the rule fails loudly.
count_matches() {
    local pattern="$1"
    shift
    { rg -o -- "$pattern" "$@" || true; } | wc -l | tr -d ' '
}
wiring=0
require() {
    local actual="$1" comparison="$2" expected="$3" message="$4"
    wiring=$(( wiring + 1 ))
    local ok=1
    case "$comparison" in
        eq) [[ "$actual" == "$expected" ]] || ok=0 ;;
        ge) [[ "$actual" -ge "$expected" ]] || ok=0 ;;
    esac
    if [[ "$ok" == "0" ]]; then
        print -u2 "$message (found $actual, expected $comparison $expected)"
        exit 1
    fi
}

transcription="$app/Services/PushToTalkTranscriptionService.swift"
provisioner="$app/Services/SpeechModelProvisioner.swift"
translation="$app/Services/InterpreterTranslationService.swift"
adapters="$app/Services/InterpreterAdapters.swift"
standins="$app/Services/InterpreterSimulatorStandIns.swift"
coordinator="$app/Services/SpeechTranslationCoordinator.swift"
screen="$app/Views/InterpreterView.swift"
button="$app/Views/Components/HoldToSpeakButton.swift"
interpreter_files=("$transcription" "$provisioner" "$translation" "$adapters" "$standins" "$coordinator" "$screen" "$button")

# Release must finalize, then let the results stream end by itself. Without
# the finalize call the stream never ends; cancelling it instead drops the
# last words.
require "$(count_matches 'try await analyzer\.finalizeAndFinishThroughEndOfInput\(\)' "$transcription")" eq 1 \
    "Release no longer finalizes the recognizer through the end of input"
require "$(count_matches 'await resultsEnded\.wait\(\)' "$transcription")" eq 1 \
    "Release no longer waits for the results stream to end by itself"
require "$(count_matches 'cancelAndFinishNow\(\)' "$transcription")" ge 3 \
    "A discarded turn no longer cancels the recognizer"
require "$(count_matches 'InterpreterTuning\.finalizationTimeout' "$transcription")" eq 1 \
    "Finalization lost its watchdog; a stalled recognizer would hang the screen"

# No sample rate is assumed anywhere: the microphone names its format and the
# recognizer names the one it wants.
require "$(count_matches '\b(8|16|22|24|32|44|48)_?(000|050|100)\b' "$transcription" "$provisioner")" eq 0 \
    "A sample rate is hardcoded in the speech services"
require "$(count_matches 'inputNode\.outputFormat\(forBus: 0\)' "$transcription")" eq 1 \
    "The microphone's own format is no longer read from the input node"
require "$(count_matches 'bestAvailableAudioFormat\(' "$transcription")" eq 2 \
    "The recognizer is no longer asked which audio format it wants"
require "$(count_matches 'AVAudioConverter\(from: inputFormat, to: recognizer\.format\)' "$transcription")" eq 1 \
    "Microphone audio is no longer converted to the recognizer's format"

# The microphone tap opens before the analyzer starts, so the first word is
# kept; and the block is built outside the main actor, which is not where the
# audio engine calls it.
require "$(count_matches 'nonisolated private enum MicrophoneTap' "$transcription")" eq 1 \
    "The tap block is no longer built in a nonisolated type"
tap_line=$(rg -n 'try capture\.start\(block:' "$transcription" | head -1 | cut -d: -f1)
start_line=$(rg -n 'analyzer\.start\(inputSequence: stream\)' "$transcription" | head -1 | cut -d: -f1)
require "$(( ${tap_line:-0} > 0 && ${start_line:-0} > ${tap_line:-0} ))" eq 1 \
    "The analyzer now starts before the microphone tap opens"

# Readiness is decided by the asset inventory for the module that will run,
# not by the list of installed locales, and partial results need the faster
# reporting mode to arrive while the button is still held.
require "$(count_matches 'AssetInventory\.status\(forModules:' "$provisioner" "$transcription")" ge 4 \
    "Speech readiness is no longer decided by AssetInventory.status(forModules:)"
require "$(count_matches 'reportingOptions: \[\.volatileResults, \.fastResults\]' "$provisioner")" eq 1 \
    "The recognizer no longer asks for volatile, fast results"
require "$(count_matches 'SpeechTranscriber\.isAvailable' "$provisioner")" eq 1 \
    "The hardware check that selects the dictation fallback is gone"
require "$(count_matches 'DictationTranscriber\(locale: locale, preset: \.progressiveShortDictation\)' "$provisioner")" eq 1 \
    "The dictation fallback is gone"

# Translation: installed sessions only, the download requested from the view,
# and a labeled stand-in in the Simulator.
require "$(count_matches 'installedSource: source' "$translation")" eq 2 \
    "Translation no longer uses installed-languages sessions, with and without a strategy"
require "$(count_matches 'preferredStrategy: lowLatency \? \.lowLatency : \.highFidelity' "$translation")" eq 1 \
    "The translation strategy is no longer chosen explicitly"
require "$(count_matches '\.translationTask\(translationRequest\)' "$screen")" eq 1 \
    "The screen no longer hosts the translation-language request"
require "$(count_matches 'session\.prepareTranslation\(\)' "$screen")" eq 1 \
    "The screen no longer asks the system to prepare the translation languages"
require "$(count_matches '\[Simulator Mock Translation\]' "$standins")" eq 1 \
    "The Simulator translation stand-in lost its label"
require "$(count_matches '\[Simulator Mock Transcript\]' "$standins")" eq 1 \
    "The Simulator transcript stand-in lost its label"
require "$(count_matches '#if targetEnvironment\(simulator\)' "$standins" "$adapters")" eq 2 \
    "The Simulator stand-ins are no longer confined to Simulator builds"
muted_flags=$({ rg -l --glob '*.swift' -- '-InterpreterSimulatorMuted' "$app" || true; } | wc -l | tr -d ' ')
require "$muted_flags" eq 1 \
    "The muted-speech launch argument must exist only in the Simulator stand-ins"
require "$(count_matches '"-InterpreterSimulatorMuted"' "$standins")" eq 1 \
    "The Simulator stand-ins lost the muted-speech launch argument"

# The system runs one translation at a time and a started one cannot be
# cancelled, so one worker serves them all; and a turn keeps its model warm
# while the button is held, which is what keeps the wait after release short.
require "$(count_matches 'Task\.detached\(priority: \.userInitiated\)' "$translation")" eq 1 \
    "Translation no longer runs on a single worker"
require "$(count_matches 'keepTranslationWarm\(activityID: id, direction: direction, model: model\)' "$coordinator")" eq 1 \
    "A press no longer keeps the turn's translation model warm"
require "$(count_matches 'await translator\.warm\(direction, model: model\)' "$coordinator")" eq 1 \
    "A held button no longer touches the translation model"
require "$(count_matches 'coordinator\.offersTranslationChoice' "$screen")" eq 1 \
    "The translation setting is no longer limited to devices that have two models"

# One speech router, one audio-session owner.
# The self-test renders speech to memory with a synthesizer of its own; it
# plays nothing and is in no shipping build, so it is not counted.
synthesizers=$({ rg -o --glob '*.swift' --glob '!InterpreterSelfTest.swift' -- 'AVSpeechSynthesizer\(\)' "$app" || true; } | wc -l | tr -d ' ')
require "$synthesizers" eq 1 \
    "A second AVSpeechSynthesizer exists; SpeechService must stay the only one"
require "$(count_matches 'AVAudioSession' "${interpreter_files[@]}")" eq 0 \
    "An Interpreter file touches AVAudioSession directly instead of the coordinator"
require "$(count_matches 'MiniMax(AudioClient|SpeechPipeline)' "${interpreter_files[@]}")" eq 0 \
    "An Interpreter file calls MiniMax directly instead of going through SpeechService"
require "$(count_matches 'pin\(\.speechConversation, owner: sessionOwner\)' "$adapters")" eq 1 \
    "The conversation no longer pins the audio session"
require "$(count_matches 'options: \[\.defaultToSpeaker, \.allowBluetoothHFP\]' "$app/Services/AudioSessionCoordinator.swift")" eq 1 \
    "The conversation profile no longer routes replies to the loudspeaker"

# Press and release, not a long press.
require "$(count_matches 'DragGesture\(minimumDistance: 0' "$button")" eq 1 \
    "The hold button no longer uses a zero-distance drag for press and release"
require "$(count_matches '@GestureState private var isPressed' "$button")" eq 1 \
    "The hold button no longer ends the press when the system cancels the gesture"
require "$(count_matches '\.onLongPressGesture' "$button" "$screen")" eq 0 \
    "The Interpreter uses onLongPressGesture, which starts late and breaks on drift"
# Every phase of the Space bar is handled: the repeats a held key sends would
# otherwise reach the system, which answers each with its alert sound.
require "$(count_matches '\.onKeyPress\(\.space, phases: \.all\)' "$screen")" eq 1 \
    "Holding Space no longer works as hold-to-speak, or its key repeats go unhandled again"
# The scene going inactive, the window losing focus, and the keyboard's focus
# leaving while Space is down each end a held press.
require "$(count_matches 'endHeldPress\(\)' "$screen")" eq 4 \
    "A held press is no longer ended when the scene, the window or the keyboard focus is lost"
require "$(count_matches 'coordinator\.sceneBecameInactive\(\)' "$screen")" eq 1 \
    "Ending a held press no longer tells the coordinator the press cannot be trusted"
# A touch that lands while a button is unavailable is delivered when the
# button becomes available; turning hit-testing off would lose it.
require "$(count_matches 'allowsHitTesting' "$button")" eq 0 \
    "The hold button stops tracking a touch while it is unavailable"
require "$(count_matches 'if old == \.unavailable, new != \.unavailable, isPressed' "$button")" eq 1 \
    "The hold button no longer delivers a press that was waiting for it to become available"
# Each input, the Space bar and a button, keeps the press it was given, and
# only when the press was taken; its release hands that press back. A release
# by direction would let one input end a turn another input is holding.
require "$(count_matches 'if let press = coordinator\.pressDown\(' "$screen")" eq 2 \
    "An input no longer keeps its press only when the coordinator took it"
require "$(count_matches 'coordinator\.pressUp\(press\)' "$screen")" eq 2 \
    "A release no longer hands back the press its input was given"
require "$(count_matches 'coordinator\.pressUp\(direction\)|coordinator\.pressUp\(\)' "$screen")" eq 0 \
    "The screen releases a press by direction again, which can end another input's turn"
# A screen that goes away while one of its inputs is down gives up that
# press, and only that one: another Interpreter window may be open.
require "$(count_matches 'giveUpOwnPresses\(\)' "$screen")" eq 2 \
    "A screen that disappears no longer gives up the presses it was holding"
require "$(count_matches 'coordinator\.cancelPress\(press\)' "$screen")" eq 2 \
    "Giving up a screen's presses no longer names them, so it could end another window's"

# Entry points: the macOS sidebar, the Study hub, the Translate toolbar and
# the deep link, and no navigation stack of its own.
require "$(count_matches 'toolTabs: \[AppTab\] = \[[^]]*\.interpreter' "$app/ContentView.swift")" eq 1 \
    "The Interpreter is missing from the macOS sidebar"
require "$(count_matches 'hosted \{ InterpreterView\(\) \}' "$app/ContentView.swift")" eq 1 \
    "The macOS detail column no longer hosts the Interpreter"
require "$(count_matches 'path\.append\(StudyRoute\.interpreter\)' "$app/Views/StudyHubView.swift")" eq 1 \
    "The Study hub row for the Interpreter is gone"
require "$(count_matches 'case \.interpreter: InterpreterView\(\)' "$app/Views/StudyHubView.swift")" eq 1 \
    "The Study hub no longer pushes the Interpreter"
require "$(count_matches 'InterpreterView\(\)' "$app/Views/TranslateView.swift")" eq 1 \
    "The Translate toolbar link to the Interpreter is gone"
require "$(count_matches 'case "interpreter": selectedTab = \.interpreter' "$app/Models/AppRouteStore.swift")" eq 1 \
    "The Interpreter deep link is gone"
# The one NavigationStack in the file belongs to its preview.
require "$(count_matches 'NavigationStack \{' "$screen")" eq 1 \
    "The Interpreter screen wraps itself in its own NavigationStack"

# Every string the feature shows must carry a Simplified Chinese translation,
# or the 中文 interface falls back to English on this screen.
python3 - "$app/Localizable.xcstrings" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    strings = json.load(handle)["strings"]

required = [
    "Interpreter",
    "The Interpreter needs iOS 26 or macOS 26 or later.",
    "The Interpreter needs the microphone. Allow microphone access in Settings and try again.",
    "This device cannot recognize %@ speech on its own.",
    "The speech models for English and Chinese need to be downloaded first.",
    "The speech models could not be downloaded: %@",
    "The microphone could not start: %@",
    "Speech recognition stopped: %@",
    "Speech recognition took too long to finish. Please try again.",
    "The microphone changed while you were speaking. Hold the button and try again.",
    "The English and Chinese translation languages need to be downloaded first.",
    "The translation could not be spoken: %@",
    "Hold the button while you speak, then let go.",
    "Didn't catch that. Hold the button and try again.",
    "Speak, and hear it translated",
    "Listening…",
    "Finishing…",
    "Translating…",
    "Downloading the speech models…",
    "Checking what is installed…",
    "Download",
    "Microphone access is turned off for SwiftMandarin.",
    "The MiniMax voice needs an API key. Add one in AI Audio settings, or choose the system voice.",
    "System Voice",
    "MiniMax AI Voice",
    "Automatic",
    "Natural",
    "Fast",
    "Translation",
    "Translation took too long. Please try again.",
    "Clear Conversation",
    "Interpreter Options",
    "Replay",
    "Copied",
    "Double-tap to start speaking, and double-tap again to stop.",
    "Press to start speaking, and press again to stop.",
    "Reply Voice",
    "Space",
    "Hold a button, speak, and hear it in the other language",
    "Interpreter Voice",
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
    sys.stderr.write("Interpreter strings are missing a zh-Hans translation (%d):\n" % len(missing))
    for key in missing[:8]:
        sys.stderr.write("  %r\n" % key)
    sys.exit(1)
PY
wiring=$(( wiring + 1 ))

print "Interpreter wiring checks passed ($wiring/$wiring)"
