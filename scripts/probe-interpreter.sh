#!/bin/zsh

# Measurement tool for the push-to-talk interpreter. Not a pass/fail check and
# not part of init.sh: it reports what this machine's Speech and Translation
# frameworks can do and how long each stage takes.
#
#   zsh scripts/probe-interpreter.sh capabilities   read-only
#   zsh scripts/probe-interpreter.sh translation    read-only
#   zsh scripts/probe-interpreter.sh translation-behaviour   read-only: repeatability, context, cancellation, concurrency
#   zsh scripts/probe-interpreter.sh speech         may install speech assets
#   zsh scripts/probe-interpreter.sh simulator      capabilities inside a booted iOS simulator
#
# Audio clips are synthesized with `say` into a temporary folder; no audio is
# written to the repository.

set -euo pipefail

repo_root="${0:A:h:h}"
source_file="$repo_root/scripts/interpreter-checks/InterpreterProbe.swift"
work="${TMPDIR:-/tmp}/swiftmandarin-interpreter-probe"
developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
mkdir -p "$work"

build_host() {
    DEVELOPER_DIR="$developer_dir" xcrun swiftc \
        "$source_file" \
        -D INTERPRETER_PROBE \
        -swift-version 6 \
        -strict-concurrency=complete \
        -warnings-as-errors \
        -parse-as-library \
        -O \
        -o "$work/probe"
}

build_simulator() {
    # `xcrun --sdk` sets SDKROOT for the linker as well as the compiler;
    # passing only `-sdk` to swiftc links against the macOS sysroot.
    DEVELOPER_DIR="$developer_dir" xcrun --sdk iphonesimulator swiftc \
        "$source_file" \
        -D INTERPRETER_PROBE \
        -swift-version 6 \
        -strict-concurrency=complete \
        -warnings-as-errors \
        -parse-as-library \
        -O \
        -target arm64-apple-ios26.0-simulator \
        -o "$work/probe-simulator"
}

make_clips() {
    say -v "Samantha" -o "$work/english.aiff" "Where is the nearest train station? I need to buy two tickets to Shanghai."
    say -v "Tingting" -o "$work/chinese.aiff" "请问最近的火车站在哪里？我想买两张去上海的票。"
}

command="${1:-capabilities}"
case "$command" in
    capabilities|translation|translation-behaviour)
        build_host
        "$work/probe" "$command"
        ;;
    speech)
        build_host
        make_clips
        shift
        "$work/probe" speech en-US "$work/english.aiff" "$@"
        "$work/probe" speech zh-CN "$work/chinese.aiff" "$@"
        ;;
    simulator)
        build_simulator
        device="${2:-booted}"
        DEVELOPER_DIR="$developer_dir" xcrun simctl spawn "$device" "$work/probe-simulator" capabilities
        ;;
    simulator-speech)
        # SpeechTranscriber does not exist in the Simulator, so this runs the
        # dictation fallback there. It may install speech assets into the
        # simulator.
        build_simulator
        make_clips
        device="${2:-booted}"
        DEVELOPER_DIR="$developer_dir" xcrun simctl spawn "$device" "$work/probe-simulator" \
            speech en-US "$work/english.aiff" --dictation
        DEVELOPER_DIR="$developer_dir" xcrun simctl spawn "$device" "$work/probe-simulator" \
            speech zh-CN "$work/chinese.aiff" --dictation
        ;;
    *)
        print -u2 "usage: probe-interpreter.sh capabilities | translation | translation-behaviour | speech [--dictation] [--fast-results] [--unpaced] | simulator [device] | simulator-speech [device]"
        exit 2
        ;;
esac
