#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
binary_path="${TMPDIR:-/tmp}/swiftmandarin-ai-prompt-checks"
service_file="$repo_root/SwiftMandarin/Services/AIWordExplanationService.swift"
translation_files=(
    "$repo_root/SwiftMandarin/Services/AIWordExplanationService.swift"
    "$repo_root/SwiftMandarin/Services/OllamaService.swift"
    "$repo_root/SwiftMandarin/Services/CloudAIService.swift"
)

# The opt-in flag keeps this standalone runner inert if it is ever discovered
# by an Xcode source group.
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}" \
    xcrun swiftc \
    "$repo_root/SwiftMandarin/Services/AIExplanationPromptBuilder.swift" \
    "$repo_root/scripts/ai-prompt-checks/AIExplanationPromptChecksRunner.swift" \
    -D AI_PROMPT_CHECKS \
    -parse-as-library \
    -o "$binary_path"

"$binary_path"

explanation_request_count=$(rg -o 'AIExplanationPromptBuilder\.explanationRequest' "$service_file" | wc -l | tr -d ' ')
teacher_instruction_count=$(rg -o 'AIExplanationPromptBuilder\.teacherInstructions' "$service_file" | wc -l | tr -d ' ')
translation_instruction_count=$(rg -o 'AITranslationPromptBuilder\.instructions' "${translation_files[@]}" | wc -l | tr -d ' ')
translation_request_count=$(rg -o 'AITranslationPromptBuilder\.request' "${translation_files[@]}" | wc -l | tr -d ' ')
semantic_validation_count=$(rg -o 'try validateExplanation\(result, direction: direction\)' "$service_file" | wc -l | tr -d ' ')

[[ "$explanation_request_count" == "3" ]] || {
    print -u2 "Expected all 3 explanation providers to use the shared request; found $explanation_request_count"
    exit 1
}
[[ "$teacher_instruction_count" == "3" ]] || {
    print -u2 "Expected all 3 explanation providers to use the shared teacher contract; found $teacher_instruction_count"
    exit 1
}
[[ "$translation_instruction_count" == "3" ]] || {
    print -u2 "Expected all 3 translation providers to use the shared instructions; found $translation_instruction_count"
    exit 1
}
[[ "$translation_request_count" == "3" ]] || {
    print -u2 "Expected all 3 translation providers to use the shared request; found $translation_request_count"
    exit 1
}
[[ "$semantic_validation_count" == "3" ]] || {
    print -u2 "Expected all 3 explanation providers to reject empty teaching output; found $semantic_validation_count"
    exit 1
}

print "AI provider wiring checks passed (15/15)"
