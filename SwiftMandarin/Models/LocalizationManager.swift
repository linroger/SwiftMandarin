//
//  LocalizationManager.swift
//  SwiftMandarin
//
//  In-app language switching between the English and Mandarin (简体中文)
//  versions of the app, independent of the device's system language.
//
//  How it works
//  ------------
//  The UI is built almost entirely from SwiftUI string literals
//  (`Text("…")`, `Label("…")`, `.navigationTitle("…")`, …) which Xcode
//  extracts into `Localizable.xcstrings`. At runtime every one of those
//  resolves through `Bundle.main.localizedString(forKey:value:table:)`.
//
//  To switch language live — without forcing the user to change their device
//  language or relaunch — we swap `Bundle.main`'s class for a subclass that
//  redirects that one method to whichever `.lproj` the user picked. Combined
//  with re-keying the view tree (`.id(language)`) and updating the
//  `\.locale` environment, the whole app flips between English and Chinese
//  the moment the toggle changes. This is the standard, App-Store-safe
//  technique for an in-app language picker; it uses only public ObjC runtime
//  APIs and needs no entitlements.
//

import Foundation
import SwiftUI

// MARK: - App Language

/// The two UI languages the app ships. Raw values are the `.lproj` / locale
/// identifiers so they map directly onto bundle lookups and `Locale`.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    /// Name shown in its own language so each option is recognizable
    /// regardless of the currently active UI language.
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    /// SF Symbol used next to the option in the language picker.
    /// (`character.book.closed.fill.zh` requires iOS 18+, so use a symbol
    /// available on every supported OS.)
    var iconName: String {
        switch self {
        case .english: return "a.circle"
        case .chinese: return "character.book.closed.fill"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    /// Nonisolated snapshot of the persisted UI language, for contexts that
    /// cannot hop to the main actor (e.g. App Intents entity display).
    /// Mirrors `LocalizationManager`'s persistence key and first-launch
    /// default (device language when Chinese, otherwise English).
    static var persisted: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: raw) {
            return language
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("zh") ? .chinese : .english
    }
}

// MARK: - Localization Manager

/// Observable, app-wide controller for the in-app UI language.
///
/// Changing `language` persists the choice, repoints `Bundle.main` at the
/// matching `.lproj`, and (because it is `@Observable`) drives a SwiftUI
/// refresh wherever the value is read — see `SwiftMandarinApp` which keys the
/// root view's identity to it.
@Observable
@MainActor
final class LocalizationManager {

    static let shared = LocalizationManager()

    private enum Keys {
        static let appLanguage = "app_language"
    }

    /// The active UI language. Setting it persists the choice and updates the
    /// active localization bundle so subsequent string lookups switch over.
    /// The interface language doubles as the user's NATIVE language, so the
    /// learner-mode preference is kept in sync: a 中文 interface means a native
    /// Mandarin speaker learning English, and vice versa.
    var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Keys.appLanguage)
            Bundle.setLanguageOverride(language.rawValue)
            AppPreferences.shared.syncLearnerMode(toInterfaceLanguage: language)
        }
    }

    /// The interface language is treated as the user's native language.
    var nativeIsChinese: Bool { language == .chinese }

    /// The language the user is learning — always the opposite of the UI
    /// language (中文 UI → learning English; English UI → learning Mandarin).
    var learningIsChinese: Bool { language == .english }

    /// Locale to inject into the SwiftUI environment so number/date/plural
    /// formatting matches the chosen UI language.
    var locale: Locale { language.locale }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Keys.appLanguage)
        let initial = saved.flatMap(AppLanguage.init(rawValue:)) ?? Self.systemDefault()
        self.language = initial
        // Apply immediately so the very first frame already renders in the
        // selected language (this runs at app construction, before any view).
        Bundle.setLanguageOverride(initial.rawValue)
    }

    /// First-launch default: follow the device language when it is Chinese,
    /// otherwise fall back to English.
    private static func systemDefault() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("zh") ? .chinese : .english
    }

    /// Flip between the two languages (used by a simple toggle control).
    func toggle() {
        language = (language == .english) ? .chinese : .english
    }

    /// Resolve a localization key against the currently selected language.
    /// Use this for user-facing strings that are *not* SwiftUI string-literal
    /// `Text`/`Label` (e.g. strings assembled in services or passed verbatim).
    /// Reading `language` here registers a SwiftUI dependency so call sites
    /// inside a view body re-evaluate when the language changes.
    func localized(_ key: String, table: String? = nil) -> String {
        _ = language
        return Bundle.main.localizedString(forKey: key, value: key, table: table)
    }
}

/// Convenience free function for the common case.
/// `Text(L("Some key"))` shows the translated string and reacts to language
/// changes when used inside a view body.
@MainActor
func L(_ key: String) -> String {
    LocalizationManager.shared.localized(key)
}

// MARK: - Localized presentation surfaces

extension View {
    /// Re-applies the in-app UI language to a presented surface (a `.sheet`,
    /// `.fullScreenCover`, or `.popover`). Such surfaces are hosted in a fresh
    /// context that does NOT reliably inherit the root window's `\.locale`
    /// environment, so without this their text stays in the device language
    /// instead of the user's chosen app language. Apply it to the root view
    /// inside every presentation closure.
    func localizedSurface() -> some View {
        modifier(LocalizedSurfaceModifier())
    }
}

private struct LocalizedSurfaceModifier: ViewModifier {
    @State private var localization = LocalizationManager.shared
    func body(content: Content) -> some View {
        content
            .environment(\.locale, localization.locale)
            .id(localization.language)
    }
}
