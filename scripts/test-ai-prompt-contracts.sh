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
    "$repo_root/SwiftMandarin/Models/LanguageBundleOverride.swift" \
    "$repo_root/SwiftMandarin/Services/AIExplanationPromptBuilder.swift" \
    "$repo_root/SwiftMandarin/Services/AIResponseParsing.swift" \
    "$repo_root/scripts/ai-prompt-checks/AIExplanationPromptChecksRunner.swift" \
    -D AI_PROMPT_CHECKS \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -parse-as-library \
    -o "$binary_path"

"$binary_path"

explanation_request_count=$(rg -o 'AIExplanationPromptBuilder\.explanationRequest' "$service_file" | wc -l | tr -d ' ')
teacher_instruction_count=$(rg -o 'AIExplanationPromptBuilder\.teacherInstructions' "$service_file" | wc -l | tr -d ' ')
translation_instruction_count=$(rg -o 'AITranslationPromptBuilder\.instructions' "${translation_files[@]}" | wc -l | tr -d ' ')
translation_request_count=$(rg -o 'AITranslationPromptBuilder\.request' "${translation_files[@]}" | wc -l | tr -d ' ')
semantic_validation_count=$(rg -o 'try validateExplanation\(result, direction: direction\)' "$service_file" | wc -l | tr -d ' ')
# Every translation provider must hand its completion to the shared parser
# rather than returning raw model prose: Apple Intelligence reads the typed
# field it generated, Ollama and the cloud parse the JSON envelope.
# `rg` exits non-zero when a pattern is absent, which under `pipefail` would
# abort the run before the check below can explain what is missing. Count the
# matching lines instead so every failure arrives as a readable message.
count_matches() {
    local pattern="$1"
    shift
    { rg -o -- "$pattern" "$@" || true; } | wc -l | tr -d ' '
}
count_files() {
    local pattern="$1"
    shift
    { rg -l -- "$pattern" "$@" || true; } | wc -l | tr -d ' '
}

apple_typed_translation=$(count_matches 'generating: TranslationOutput\.self' "$service_file")
apple_translation_parse=$(count_matches 'AITranslationResponseParser\.sanitizedEnvelopeValue\(output\.translation\)' "$service_file")
ollama_translation_parse=$(count_matches 'AITranslationResponseParser\.result\(' "$repo_root/SwiftMandarin/Services/OllamaService.swift")
cloud_translation_parse=$(count_matches 'AITranslationResponseParser\.result\(' "$repo_root/SwiftMandarin/Services/CloudAIService.swift")
json_contract_count=$(count_matches 'AITranslationPromptBuilder\.jsonOutputContract' "${translation_files[@]}")
# No provider may return a raw completion as a translation again.
raw_translation_returns=$(count_files 'return content\.trimmingCharacters|return response\.content\.trimmingCharacters|return result\.trimmingCharacters' "${translation_files[@]}")
# Both cloud chat entry points must strip inline chain-of-thought.
reasoning_strip_count=$(count_matches 'Self\.answerText\(from:' "$repo_root/SwiftMandarin/Services/CloudAIService.swift")

transcription_file="$repo_root/SwiftMandarin/Services/AudioTranscriptionService.swift"
# `supportsOnDeviceRecognition` only says the recognizer *can* work offline; it
# does not promise the locale's assets are installed. Forcing on-device with no
# retry is what made transcription look broken, so the flag must stay a
# parameter and the service must keep a server pass to fall back to.
forced_on_device=$(count_matches 'requiresOnDeviceRecognition = true' "$transcription_file")
server_fallback_passes=$(count_matches 'runRecognition\(recognizer: recognizer, audioURL: audioURL, onDevice: false\)' "$transcription_file")
# A recognition pass must be able to give up: Speech can accept a URL request
# and never call back.
recognition_timeout=$(count_matches 'AudioTranscriptionError\.timedOut' "$transcription_file")
# AI transcription is a real alternative engine, routed in the service.
ai_transcription_route=$(count_matches 'CloudAIService\.shared\.transcribeAudio' "$transcription_file")
ai_transcription_client=$(count_matches 'func transcribeAudio\(' "$repo_root/SwiftMandarin/Services/CloudAIService.swift")
# Study notes must actually reach a screen, on both translation surfaces.
notes_surfaces=$(count_files 'TranslationNotesView\(' "$repo_root/SwiftMandarin/Views/TranslateView.swift" "$repo_root/SwiftMandarin/Views/PhotoTranslateView.swift")
detailed_translation=$(count_matches 'translateDetailedWithProvider\(' "$repo_root/SwiftMandarin/Views/TranslateView.swift" "$repo_root/SwiftMandarin/Views/PhotoTranslateView.swift")

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
[[ "$apple_typed_translation" == "1" ]] || {
    print -u2 "Expected the Apple Intelligence translation to use guided generation; found $apple_typed_translation"
    exit 1
}
[[ "$apple_translation_parse" == "1" ]] || {
    print -u2 "Expected the Apple Intelligence translation to read its generated field through the shared parser; found $apple_translation_parse"
    exit 1
}
[[ "$ollama_translation_parse" == "1" ]] || {
    print -u2 "Expected the Ollama translation to parse its response through the shared parser; found $ollama_translation_parse"
    exit 1
}
[[ "$cloud_translation_parse" == "1" ]] || {
    print -u2 "Expected the cloud translation to parse its response through the shared parser; found $cloud_translation_parse"
    exit 1
}
[[ "$json_contract_count" == "2" ]] || {
    print -u2 "Expected the 2 prompt-driven translation providers (Ollama, cloud) to request the JSON envelope; found $json_contract_count"
    exit 1
}
[[ "$raw_translation_returns" == "0" ]] || {
    print -u2 "A translation provider returns a raw model completion instead of a parsed one ($raw_translation_returns file(s))"
    exit 1
}
[[ "$reasoning_strip_count" == "2" ]] || {
    print -u2 "Expected both cloud chat entry points to strip inline reasoning; found $reasoning_strip_count"
    exit 1
}
[[ "$forced_on_device" == "0" ]] || {
    print -u2 "Transcription forces on-device recognition with no fallback ($forced_on_device site(s))"
    exit 1
}
[[ "$server_fallback_passes" == "2" ]] || {
    print -u2 "Expected a server recognition pass for both the unsupported and the failed-on-device case; found $server_fallback_passes"
    exit 1
}
[[ "$recognition_timeout" -ge 1 ]] || {
    print -u2 "A stalled recognition has no timeout; found $recognition_timeout"
    exit 1
}
[[ "$ai_transcription_route" == "1" ]] || {
    print -u2 "Expected the transcription service to route the AI engine to the cloud client; found $ai_transcription_route"
    exit 1
}
[[ "$ai_transcription_client" == "1" ]] || {
    print -u2 "Expected one cloud speech-to-text client; found $ai_transcription_client"
    exit 1
}
[[ "$notes_surfaces" == "2" ]] || {
    print -u2 "Expected translation notes on both the Translate and Multimodal surfaces; found $notes_surfaces"
    exit 1
}
[[ "$detailed_translation" -ge 2 ]] || {
    print -u2 "Expected both surfaces to request the notes-bearing translation; found $detailed_translation"
    exit 1
}

print "AI provider wiring checks passed (29/29)"
