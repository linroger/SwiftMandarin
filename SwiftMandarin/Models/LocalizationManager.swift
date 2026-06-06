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
    var iconName: String {
        switch self {
        case .english: return "a.circle"
        case .chinese: return "character.book.closed.fill.zh"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
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
    var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Keys.appLanguage)
            Bundle.setLanguageOverride(language.rawValue)
        }
    }

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

// MARK: - Runtime bundle override

private var bundleLanguageAssociationKey: UInt8 = 0

extension Bundle {

    /// Swap `Bundle.main`'s class exactly once so its localized-string lookups
    /// can be redirected at runtime. Idempotent and thread-safe.
    private static let installLanguageOverrideOnce: Void = {
        object_setClass(Bundle.main, LanguageOverrideBundle.self)
    }()

    /// Point `Bundle.main` at the `.lproj` for `code` (e.g. `"zh-Hans"`).
    /// If that `.lproj` is missing (e.g. the source language has no compiled
    /// `.lproj`), the override is cleared and lookups fall back to the normal
    /// bundle, which already serves the development-language strings.
    static func setLanguageOverride(_ code: String?) {
        _ = installLanguageOverrideOnce
        let override: Bundle?
        if let code,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            override = languageBundle
        } else {
            override = nil
        }
        objc_setAssociatedObject(
            Bundle.main,
            &bundleLanguageAssociationKey,
            override,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    /// The currently installed override bundle, if any.
    fileprivate var languageOverrideBundle: Bundle? {
        objc_getAssociatedObject(self, &bundleLanguageAssociationKey) as? Bundle
    }
}

/// `Bundle.main` is reclassed to this so all localized-string lookups —
/// including the ones SwiftUI performs for `Text("…")` — can be routed to the
/// user-selected language bundle. Adds no stored properties (required for
/// `object_setClass` to be safe).
private final class LanguageOverrideBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let override = languageOverrideBundle {
            return override.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
