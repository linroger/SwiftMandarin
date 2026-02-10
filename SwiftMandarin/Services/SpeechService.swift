//
//  SpeechService.swift
//  SwiftMandarin
//
//  Text-to-speech service for Chinese and English
//

import AVFoundation

enum SpeechService {
    private static let synthesizer = AVSpeechSynthesizer()
    
    static func speak(_ text: String, languageCode: String? = nil) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        if let languageCode {
            utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
    
    static func speakChinese(_ text: String) {
        speak(text, languageCode: "zh-CN")
    }
    
    static func speakEnglish(_ text: String) {
        speak(text, languageCode: "en-US")
    }
    
    static func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    static var isSpeaking: Bool {
        synthesizer.isSpeaking
    }
}
