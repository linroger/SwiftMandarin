//
//  CompatModifiers.swift
//  SwiftMandarin
//
//  Backward-compatibility wrappers so the app runs on iOS 17 while still
//  adopting the newest APIs on current OS releases. Each wrapper applies the
//  modern API when available and a faithful material/border fallback earlier.
//

import SwiftUI
import Translation

// MARK: - Apple Translation (iOS 18+/macOS 15+)

/// Version-agnostic stand-in for an optional `TranslationSession.Configuration`
/// stored property. Views deploying to iOS 17 cannot store the iOS 18-only
/// type directly, so the configuration lives in an `Any?` box and is only
/// touched behind availability checks. The `version` token changes on every
/// mutation so SwiftUI change-tracking sees create/invalidate/clear.
struct TranslationConfigurationBox: Equatable {
    private(set) var version: Int = 0
    private var storage: Any?

    var isNil: Bool { storage == nil }

    @available(iOS 18.0, macOS 15.0, *)
    var configuration: TranslationSession.Configuration? {
        storage as? TranslationSession.Configuration
    }

    /// Install a fresh configuration (triggers the translation task).
    @available(iOS 18.0, macOS 15.0, *)
    mutating func set(source: Locale.Language?, target: Locale.Language?) {
        storage = TranslationSession.Configuration(source: source, target: target)
        version += 1
    }

    /// Re-trigger the translation task with the existing configuration.
    @available(iOS 18.0, macOS 15.0, *)
    mutating func invalidate() {
        guard var config = storage as? TranslationSession.Configuration else { return }
        config.invalidate()
        storage = config
        version += 1
    }

    /// Drop the configuration (cancels/parks the translation task).
    mutating func clear() {
        guard storage != nil else { return }
        storage = nil
        version += 1
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.version == rhs.version
    }
}

/// Invisible host that owns the `.translationTask` for a view. Mount it in a
/// `.background { if #available(...) { ... } }` so the surrounding view can
/// deploy to iOS 17 while the Translation API stays fully functional on 18+.
@available(iOS 18.0, macOS 15.0, *)
struct TranslationTaskHost: View {
    let box: TranslationConfigurationBox
    let action: (TranslationSession) async -> Void

    var body: some View {
        Color.clear
            .translationTask(box.configuration) { session in
                await action(session)
            }
    }
}

extension View {

    /// Liquid Glass surface on OS 26+, ultra-thin material earlier.
    @ViewBuilder
    func glassEffectCompat(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    /// Liquid Glass capsule on OS 26+, ultra-thin material capsule earlier.
    @ViewBuilder
    func glassEffectCapsuleCompat() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }

    /// `.buttonStyle(.glass)` on OS 26+, `.bordered` earlier.
    @ViewBuilder
    func glassButtonStyleCompat() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}
