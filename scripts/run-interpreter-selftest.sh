#!/bin/zsh

# End-to-end run of the real Interpreter pipeline inside the macOS app:
# synthesized speech goes through the real recognizer, the real translation
# models and the real state machine. See
# SwiftMandarin/Services/InterpreterSelfTest.swift.
#
#   zsh scripts/run-interpreter-selftest.sh                  silent
#   zsh scripts/run-interpreter-selftest.sh --microphone     also opens the real
#                                                            microphone for a second,
#                                                            if the app may use it
#   zsh scripts/run-interpreter-selftest.sh --audible        speaks the replies
#   zsh scripts/run-interpreter-selftest.sh --minimax        also times MiniMax,
#                                                            using the stored key
#   zsh scripts/run-interpreter-selftest.sh --no-keep-warm   does not keep the
#                                                            translation model warm
#                                                            during the hold, to
#                                                            show what that is worth
#
# Not part of init.sh: it needs a logged-in session, installed speech and
# translation assets, and opens the app's window for the length of the run.
# It builds into its own derived-data folder with the INTERPRETER_SELFTEST
# condition, so the normal builds never contain the self-test.

set -euo pipefail

repo_root="${0:A:h:h}"
derived="$repo_root/build/SelfTestDerivedData"
log="${TMPDIR:-/tmp}/swiftmandarin-interpreter-selftest-build.log"

arguments=(-InterpreterSelfTest)
for option in "$@"; do
    case "$option" in
        --audible) arguments+=(-InterpreterSelfTestAudible) ;;
        --microphone) arguments+=(-InterpreterSelfTestMicrophone) ;;
        --minimax) arguments+=(-InterpreterSelfTestMiniMax) ;;
        --no-keep-warm) arguments+=(-InterpreterSelfTestNoKeepWarm) ;;
        *) print -u2 "usage: run-interpreter-selftest.sh [--microphone] [--audible] [--minimax] [--no-keep-warm]"; exit 2 ;;
    esac
done

if ! xcodebuild \
    -project "$repo_root/SwiftMandarin.xcodeproj" \
    -scheme SwiftMandarin \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "$derived" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG INTERPRETER_SELFTEST' \
    build > "$log" 2>&1; then
    print -u2 "The self-test build failed; see $log"
    grep -E "error:" "$log" | sort -u | head -20 >&2
    exit 1
fi

"$derived/Build/Products/Debug/SwiftMandarin.app/Contents/MacOS/SwiftMandarin" "${arguments[@]}" 2>/dev/null \
    | grep --line-buffered '^SELFTEST' \
    | sed 's/^SELFTEST //'
exit ${pipestatus[1]}
