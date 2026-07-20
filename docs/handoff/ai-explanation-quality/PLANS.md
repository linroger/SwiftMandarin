# AI explanation quality plan

**Created (UTC):** 2026-07-20T17:42:19Z

**Status:** Implemented and verified locally.

## Task brief

Improve the learner-facing AI word explanation so it reads like an excellent bilingual tutor rather than a dictionary template. A generated explanation should lead with the natural target-language translation — or a non-circular plain-language definition when both languages match — and the semantic core. It should account honestly for the role of every individual Chinese character or bound morpheme, connect the parts to the whole word, explain how the word feels and behaves in real use, and remain warm, concrete, memorable, and easy to scan. The same pedagogical contract MUST reach Apple Intelligence, Ollama, and every cloud provider.

The app's plain-translation methods have a separate invariant: they feed photo translation, speech, Reader, history, TTS, and Shortcuts, so they MUST continue returning target-language text only. Rich teaching content belongs in `WordExplanationResult`; it MUST NOT be mixed into those translation strings.

## Success criteria

1. Every provider receives one shared teaching philosophy and sense-selection policy, rather than drifting provider-specific prose.
2. The prompt explicitly asks for the closest natural cross-language translation (or a non-circular same-language definition), the word's semantic essence, and a role-aware character-by-character explanation for Chinese words.
3. Character explanations distinguish modern contribution from historical etymology and MUST NOT invent radical stories or pretend every character contributes literally.
4. Nuance, grammar, examples, related words, collocations, and the learning tip each have a distinct job, avoid repetition, and provide concrete decisions or reusable patterns.
5. The prose is accurate, warm, vivid, concise enough to scan, free of canned filler, and written in the learner's interface/native language.
6. The supplied headword, pinyin, and sense hint or encounter context are delimited as untrusted study data, so saved glosses and passage text cannot silently override system instructions.
7. Existing response fields and persisted cache payloads remain compatible; no existing explanation data is discarded.
8. Deterministic checks prove both language directions, character-composition rules, style/accuracy guardrails, and provider wiring; iOS and macOS builds remain green.

## Design

The prompt will follow an answer-first teaching arc:

1. **Choose the intended sense.** Use the sense hint or encounter context and pinyin when present, without pretending a saved gloss is an attested sentence. Without a useful hint, lead with the most frequent modern sense and mention another sense only when it prevents a likely misunderstanding.
2. **Give the learner a mental model.** The definition starts with the closest natural target-language translation, or a non-circular plain-language definition in a same-language flow, then states the stable semantic core that connects real uses.
3. **Build the word from its parts.** For a multi-character Chinese word, account for every character or bound morpheme: give a core meaning only for a semantically active part, and identify phonetic, transliterated, grammatical, fossilized, or uncertain roles honestly. Then bridge those roles to the lexicalized modern meaning. For a one-character content word, explain the central semantic image; for a function word or particle, explain its grammatical or pragmatic job. For English, discuss genuine roots or affixes only when useful.
4. **Turn knowledge into choices.** Nuance, register, grammar patterns, synonyms, and common contexts tell the learner when this word is the right choice and when it is not.
5. **Make it stick.** Natural, varied examples and a truthful memory hook end with one common trap or a small recall cue.

The existing structured fields remain the output contract. Character composition and the semantic bridge live in `nuances`, while `definition` carries the direct translation plus essence. This keeps cache compatibility and avoids widening every persistence/import/export boundary for what is fundamentally a prompt-quality change.

## Increment plan

1. Map current provider prompts, structured schemas, decoders, cache behavior, and UI rendering.
2. Add a pure shared prompt builder with a single teaching contract and safely delimited request payload.
3. Route Apple Intelligence, Ollama, and cloud explanations through the shared builder; strengthen each structured-field description to reinforce the contract.
4. Add deterministic prompt checks that compile and exercise Chinese/English directions without API credentials.
5. Run prompt checks, source/diff validation, and isolated iOS/macOS builds; conduct an independent final review.
6. Record results and any residual live-provider validation gap in `handoff.md`.

## Risks and guardrails

- **Verbose walls of text:** assign each field a distinct purpose and cap prose at short paragraphs or a few concrete items.
- **Invented etymology:** explicitly distinguish present-day composition, historical origin, and optional mnemonic; require honest uncertainty.
- **Awkward examples:** require one exact-headword anchor, then permit natural inflected or separated forms of the same lexeme and selected sense; discard an unanchored set rather than forcing awkward surface forms.
- **Provider drift:** keep teaching and request instructions in one pure builder; provider schemas reinforce rather than redefine them.
- **Prompt injection through context:** serialize study inputs as JSON and state that they are data, never instructions.
- **Translation-contract breakage:** leave plain translation output as translation-only.
- **Dirty-worktree collision:** do not rewrite or stage the existing vocabulary-paging changes; restrict production edits to the AI prompt service and a new standalone prompt builder/check.

## Final local evidence

- Shared prompt and translation contracts: 75/75 deterministic assertions passed.
- Apple Intelligence, Ollama, and cloud wiring: 15/15 structural assertions passed.
- Generic iOS Simulator Debug and generic macOS Debug builds both succeeded from the final snapshot.
- Clean-branch iOS Simulator and macOS builds emit no warning or error. The primary dirty worktree's Xcode-generated duplicate Sources diff remains deliberately excluded.
- No configured live model was invoked, so factual prose quality remains a runtime sampling step rather than a locally proven claim.
