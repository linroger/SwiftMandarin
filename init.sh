#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
cd "$SCRIPT_DIR"

plutil -lint SwiftMandarin.xcodeproj/project.pbxproj >/dev/null
plutil -lint SwiftMandarin/SwiftMandarin.entitlements >/dev/null
python3 -m json.tool feature_list.json >/dev/null
python3 -m json.tool SwiftMandarin/Localizable.xcstrings >/dev/null
zsh scripts/test-minimax-audio-contracts.sh
zsh scripts/test-audio-session-transitions.sh
zsh scripts/test-ai-prompt-contracts.sh
zsh scripts/test-learning-direction.sh
zsh scripts/test-auto-analysis.sh
zsh scripts/test-audio-transcription.sh
zsh scripts/test-stats-heatmap.sh
zsh scripts/test-macos-surfaces.sh

echo "SwiftMandarin smoke checks passed."
