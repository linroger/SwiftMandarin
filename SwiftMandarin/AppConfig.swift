//
//  AppConfig.swift
//  SwiftMandarin
//
//  Centralized, build-derived app metadata and canonical external links.
//
//  Version and build are read from the generated Info.plist (driven by
//  MARKETING_VERSION / CURRENT_PROJECT_VERSION in the project file) so the
//  numbers shown to users can never drift from the actual release the way the
//  previously hard-coded "1.0.0" / "2026.02.11" strings did.
//

import Foundation

/// App-wide metadata and the canonical set of external links used by the About
/// and Settings surfaces.
enum AppConfig {

    // MARK: - Version

    /// Marketing version, e.g. "3.0" (`CFBundleShortVersionString`).
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    /// Build number, e.g. "3" (`CFBundleVersion`).
    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    /// Compact "version (build)" string for places that show both at once.
    static var versionWithBuild: String { "\(appVersion) (\(buildNumber))" }

    // MARK: - Links

    /// Numeric App Store ID, assigned by App Store Connect at first submission.
    /// While `nil` (pre-launch) the store links below fall back to the public
    /// source repository rather than pointing at a fabricated App Store URL.
    static let appStoreID: String? = nil

    /// Canonical public home for the project.
    static let repositoryURL = URL(string: "https://github.com/linroger/SwiftMandarin")!

    /// The app's own privacy policy (hosted alongside the source).
    static let privacyPolicyURL = URL(string: "https://github.com/linroger/SwiftMandarin/blob/main/PRIVACY.md")!

    /// App Store product page, or the repository while pre-launch.
    static var appStoreURL: URL {
        guard let appStoreID else { return repositoryURL }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)") ?? repositoryURL
    }

    /// Deep link that opens the App Store review sheet, or the repository while
    /// pre-launch.
    static var reviewURL: URL {
        guard let appStoreID else { return repositoryURL }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review") ?? appStoreURL
    }
}
