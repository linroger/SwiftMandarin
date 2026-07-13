#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
binary_path="${TMPDIR:-/tmp}/swiftmandarin-vocabulary-paging-checks"

# The opt-in flag leaves the external runner inert if Xcode ever sees it as an app source.
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}" \
    xcrun swiftc \
    "$repo_root/SwiftMandarin/Models/VocabularyPaging.swift" \
    "$repo_root/scripts/vocabulary-paging-checks/VocabularyPagingChecksRunner.swift" \
    -D VOCABULARY_PAGING_CHECKS \
    -parse-as-library \
    -o "$binary_path"

"$binary_path"
