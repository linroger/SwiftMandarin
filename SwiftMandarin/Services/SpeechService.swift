//
//  SpeechService.swift
//  SwiftMandarin
//
//  Text-to-speech service for Chinese and English
//

import AVFoundation
import os.log

@MainActor
enum SpeechService {
    private static let synthesizer = AVSpeechSynthesizer()
    private static let log = Logger(subsystem: "com.rogerlin.SwiftMandarin", category: "Speech")

    /// Retained delegate that releases the (ducking) audio session once speech
    /// ends, so background music/podcasts aren't left permanently ducked after
    /// a single speaker tap. Installed lazily on first use.
    private static let sessionReleaser: SpeechSessionReleaser = {
        let releaser = SpeechSessionReleaser()
        synthesizer.delegate = releaser
        return releaser
    }()

    /// Multiplier applied to the persisted rate for a learner "slow" replay.
    static let slowRateFactor: Float = 0.6

    /// Cache of the best voice found per language code — `speechVoices()`
    /// enumerates every installed voice, so scan once per language, not per
    /// utterance.
    private static var voiceCache: [String: AVSpeechSynthesisVoice] = [:]

    static func speak(_ text: String, languageCode: String? = nil) {
        speak(text, languageCode: languageCode, rate: Float(AppPreferences.shared.ttsRate))
    }

    /// Slow-replay for learners: the persisted rate scaled down so individual
    /// syllables/tones are easy to pick apart.
    static func speakSlow(_ text: String, languageCode: String? = nil) {
        speak(text, languageCode: languageCode, rate: Float(AppPreferences.shared.ttsRate) * slowRateFactor)
    }

    private static func speak(_ text: String, languageCode: String?, rate: Float) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        _ = sessionReleaser // ensure the delegate is installed
        configureAudioSessionForPlayback()

        let utterance = AVSpeechUtterance(string: text)
        if let languageCode {
            utterance.voice = bestVoice(forLanguage: languageCode)
        }
        utterance.rate = rate

        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    static func speakChinese(_ text: String) {
        speak(text, languageCode: "zh-CN")
    }

    static func speakEnglish(_ text: String) {
        speak(text, languageCode: "en-US")
    }

    /// Speak with the voice matching the text's content (CJK → Mandarin,
    /// otherwise English). Headword fields can hold either language depending
    /// on the learning direction, so callers that show direction-aware text
    /// should use this instead of hardcoding a voice.
    static func speakAuto(_ text: String) {
        if text.containsCJK {
            speakChinese(text)
        } else {
            speakEnglish(text)
        }
    }

    /// Content-aware slow replay (Mandarin vs English voice), at the learner
    /// slow rate. Used by drills where hearing each syllable clearly matters.
    static func speakAutoSlow(_ text: String) {
        speakSlow(text, languageCode: text.containsCJK ? "zh-CN" : "en-US")
    }

    static func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    static var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    // MARK: - Voice Selection

    /// Prefer an enhanced/premium voice for the language when one is
    /// installed — the default compact voices are noticeably robotic, which
    /// matters for a pronunciation-learning app. Falls back to the system
    /// default voice for the language.
    private static func bestVoice(forLanguage code: String) -> AVSpeechSynthesisVoice? {
        if let cached = voiceCache[code] { return cached }

        let matches = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == code }
        let picked: AVSpeechSynthesisVoice?
        if let premium = matches.first(where: { $0.quality == .premium }) {
            picked = premium
        } else if let enhanced = matches.first(where: { $0.quality == .enhanced }) {
            picked = enhanced
        } else {
            picked = AVSpeechSynthesisVoice(language: code)
        }

        if let picked { voiceCache[code] = picked }
        return picked
    }

    // MARK: - Audio Session (iOS)

    /// Configure the audio session for playback before each utterance. After
    /// speech recognition (which puts the session in a record category) the
    /// synthesizer would otherwise come out quiet or through the receiver —
    /// re-asserting `.playback` + `.spokenAudio` makes TTS volume
    /// deterministic. `.duckOthers` lowers background music instead of
    /// fighting it. No-op on macOS, which has no AVAudioSession.
    private static func configureAudioSessionForPlayback() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            log.error("Audio session configuration failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    /// Release the ducking session so other audio returns to full volume.
    /// Invoked by the delegate when the synthesizer finishes or is cancelled.
    fileprivate static func deactivateAudioSessionIfIdle() {
        #if os(iOS)
        guard !synthesizer.isSpeaking else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            log.error("Audio session deactivation failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }
}

/// Bridges `AVSpeechSynthesizer`'s Objective-C delegate callbacks back to
/// `SpeechService` so the ducking audio session is released once speech ends.
/// A separate object because `SpeechService` is an enum (no instances) and the
/// delegate must be a retained reference type.
private final class SpeechSessionReleaser: NSObject, AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated { SpeechService.deactivateAudioSessionIfIdle() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated { SpeechService.deactivateAudioSessionIfIdle() }
    }
}
