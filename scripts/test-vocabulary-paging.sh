#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
binary_path="${TMPDIR:-/tmp}/swiftmandarin-vocabulary-paging-checks"

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}" \
    xcrun swiftc \
    "$repo_root/SwiftMandarin/Models/VocabularyPaging.swift" \
    "$repo_root/scripts/vocabulary-paging-checks/main.swift" \
    -o "$binary_path"

"$binary_path"
