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
    ///
    /// - Parameters:
    ///   - tint: Colors the glass (for a surface that carries meaning, such as
    ///     a selected or warning state). Pass a translucent color, about 0.2–0.5
    ///     opacity: a fully opaque tint turns the glass into a solid colored
    ///     slab that hides same-colored content. The fallback lays the tint
    ///     over the material at a little over half its strength.
    ///   - interactive: Makes the glass react to touch (scale and shimmer) on
    ///     OS 26 — for a surface that is itself tappable.
    @ViewBuilder
    func glassEffectCompat(cornerRadius: CGFloat, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(
                Glass.regular.tint(tint).interactive(interactive),
                in: .rect(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            self.background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if let tint {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(tint.opacity(0.6))
                        }
                    }
            }
        }
    }

    /// Liquid Glass capsule on OS 26+, ultra-thin material capsule earlier.
    @ViewBuilder
    func glassEffectCapsuleCompat(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(Glass.regular.tint(tint).interactive(interactive), in: .capsule)
        } else {
            self.background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if let tint {
                            Capsule().fill(tint.opacity(0.6))
                        }
                    }
            }
        }
    }

    /// Liquid Glass circle on OS 26+, ultra-thin material circle earlier. For
    /// round icon buttons and badges.
    @ViewBuilder
    func glassEffectCircleCompat(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(Glass.regular.tint(tint).interactive(interactive), in: .circle)
        } else {
            self.background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if let tint {
                            Circle().fill(tint.opacity(0.6))
                        }
                    }
            }
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

// MARK: - Liquid Glass chrome (OS 26+)

extension View {

    /// On iOS 26 the tab bar shrinks to a pill while the content scrolls down
    /// and re-expands on scroll up, giving reading surfaces the full height.
    /// No-op on earlier releases and on macOS, which has no tab bar.
    @ViewBuilder
    func tabBarMinimizeOnScrollCompat() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// `.buttonStyle(.glassProminent)` on OS 26+, `.borderedProminent` earlier.
    /// For the one primary call to action on a screen.
    @ViewBuilder
    func glassProminentButtonStyleCompat() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

/// Groups neighbouring glass elements so they render as one glass surface
/// and blend when they move toward each other, instead of each sampling the
/// background independently. Transparent on releases without Liquid Glass.
struct GlassGroupCompat<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}
