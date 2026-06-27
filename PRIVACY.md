# SwiftMandarin — Privacy Policy

_Last updated: 2026-06-26_

SwiftMandarin is a Mandarin Chinese translation and learning app. It is
designed to keep your data on your device. This policy explains what the app
stores, what leaves your device, and the choices you control.

## Summary

- **No account is required.** SwiftMandarin does not ask you to sign in and does
  not collect a user identity.
- **No analytics or tracking.** The app contains no third-party analytics,
  advertising, or tracking SDKs.
- **Your learning data stays on your device** unless you explicitly export it or
  configure a third-party AI provider.

## Data stored on your device

The following are stored locally (in the app's container / `UserDefaults`) and
are never uploaded by the app itself:

- Saved vocabulary, flashcard progress, and spaced-repetition state.
- Translation history.
- Phrase library customizations.
- Workbook scans, grading results, and generated review questions.
- Cached AI word analyses.
- App preferences (interface language, learner mode, provider configuration).

You can delete this data at any time from within the app, or by removing the
app.

## Data that may leave your device

SwiftMandarin only sends data off-device for features you actively use and
configure:

- **Apple Translation.** On supported OS versions, on-device translation is used
  where available; otherwise translation is handled by Apple's Translation
  framework subject to [Apple's privacy policy](https://www.apple.com/legal/privacy/).
- **Speech recognition.** Live speech transcription uses Apple's Speech
  framework, which may process audio on-device or via Apple's services depending
  on the OS and language.
- **Third-party AI providers (optional).** If you configure a cloud AI provider
  (for example OpenAI, Anthropic/Claude, DeepSeek, Qwen, Doubao, Kimi, Zhipu, or
  MiniMax), then the text, and for some features the images, you submit for
  translation, explanation, OCR cleanup, or workbook grading are sent to that
  provider using the API key you supply. Your use of those providers is governed
  by their own privacy policies and terms. SwiftMandarin does not receive a copy
  of this traffic.
- **On-device / local models (optional).** If you configure a local Ollama
  server, requests are sent to the host you specify and do not reach the
  internet unless that host is remote.

API keys you enter are stored on your device and are sent only to the
corresponding provider when you make a request.

## Children's privacy

SwiftMandarin does not knowingly collect personal information from children and
does not require any personal information to function.

## Changes to this policy

If this policy changes, the updated version will be published at this URL with a
new "Last updated" date.

## Contact

Questions about this policy can be filed as an issue on the project's
repository: <https://github.com/linroger/SwiftMandarin>.
