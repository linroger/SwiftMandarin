//
//  LanguageBundleOverride.swift
//  SwiftMandarin
//
//  The ObjC-runtime half of the in-app language toggle, split out from
//  `LocalizationManager` so it stays Foundation-only.
//
//  Why it is its own file: every model and service that produces a
//  user-facing string resolves it with `String(localized:bundle:)` against
//  `Bundle.appLanguage`, and several of those files are compiled standalone by
//  the contract runners in `scripts/`. Keeping this dependency free of
//  SwiftUI, `AppPreferences`, and the observable manager is what lets those
//  runners include it with one extra source path instead of dragging in the
//  whole app.
//

import Foundation

// MARK: - Runtime bundle override

/// Address-only: `objc_setAssociatedObject` uses the variable's address as the
/// key and never reads its value, so there is nothing to synchronize. The
/// annotation states that for the strict-concurrency checker, which the
/// standalone contract runners compile with as an error rather than a warning.
nonisolated(unsafe) private var bundleLanguageAssociationKey: UInt8 = 0

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

    /// The bundle that app strings must be resolved against.
    ///
    /// Re-classing `Bundle.main` only redirects the ObjC method
    /// `localizedString(forKey:value:table:)`. SwiftUI's `Text("…")` and
    /// `NSLocalizedString` both go through that method, which is why view
    /// literals have always followed the in-app toggle. A bare
    /// `String(localized:)` and `LocalizedStringResource` do **not** — they resolve through
    /// Foundation's own machinery, which never calls the override, so a string
    /// assembled that way silently follows the *device* language instead.
    ///
    /// Passing this bundle explicitly (`String(localized: "…", bundle:
    /// .appLanguage)`) points that machinery straight at the selected
    /// `.lproj`, so every assembled string follows the toggle like the rest of
    /// the UI. It falls back to `.main` when no override is installed, which is
    /// the correct behaviour for the development language.
    nonisolated static var appLanguage: Bundle {
        Bundle.main.languageOverrideBundle ?? .main
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
