//
//  DesignSystem.swift
//  SwiftMandarin
//
//  Shared visual language for the 2026 overhaul: cards, section headers,
//  stat tiles, progress rings, quick actions, chips, and empty states.
//  Every component is cross-platform (iOS 17+ / macOS) and uses the
//  Liquid-Glass compat helpers so the app reads as one coherent surface.
//

import SwiftUI

// MARK: - Palette & metrics

/// Centralized colors/metrics so features don't re-derive platform colors.
enum SMTheme {
    /// Grouped-list style page background.
    ///
    /// On macOS the obvious pairing — `windowBackgroundColor` behind
    /// `controlBackgroundColor` — does not work: AppKit resolves both to the
    /// *same* value, `#FFFFFF` in Aqua and `#1E1E1E` in Dark Aqua, so every
    /// card was drawn in exactly the page color and vanished into it. The two
    /// surfaces therefore pick different system colors per appearance, always
    /// arranged so the card is the lighter one (see `cardFill`).
    static var pageBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: NSColor(name: "SMPageBackground") { appearance in
            // Dark: stay on the window color so the page meets the toolbar and
            // the window frame seamlessly, and let the card rise above it.
            // Light: drop to the page-backdrop gray so a white card can rise
            // above *it* — the same direction iOS gets from its grouped colors.
            appearance.smIsDark ? .windowBackgroundColor : .underPageBackgroundColor
        })
        #endif
    }

    /// Elevated card fill (over `pageBackground`), always the lighter of the
    /// two so cards read as raised rather than recessed on both platforms.
    static var cardFill: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: NSColor(name: "SMCardFill") { appearance in
            appearance.smIsDark ? .underPageBackgroundColor : .controlBackgroundColor
        })
        #endif
    }

    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    /// Readable content column width — keeps Home from sprawling across a wide
    /// macOS/iPad window into a lonely left-hugging strip.
    static let contentMaxWidth: CGFloat = 700
    /// Accent gradient used for hero surfaces (goal ring, primary CTAs).
    static let heroGradient = LinearGradient(
        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Hairline card border. The fills above differ by only ~10/255, which is
    /// the same gentle step iOS uses — enough once an edge is drawn, but not on
    /// its own. This is that edge, so it is at full separator strength on macOS
    /// rather than faded.
    static var cardStroke: Color {
        #if os(iOS)
        Color(uiColor: .separator).opacity(0.5)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }

    /// Soft drop shadow that lifts cards off the page background. A 6% black
    /// shadow is invisible against a `#1E1E1E` page, so the dark appearance
    /// gets a deeper one; it is what makes the card edge legible at a glance
    /// rather than only on inspection.
    static var cardShadow: Color {
        #if os(iOS)
        Color.black.opacity(0.06)
        #else
        Color(nsColor: NSColor(name: "SMCardShadow") { appearance in
            NSColor.black.withAlphaComponent(appearance.smIsDark ? 0.45 : 0.06)
        })
        #endif
    }
}

#if os(macOS)
extension NSAppearance {
    /// Whether this appearance is one of the dark variants. `name == .darkAqua`
    /// would miss `.accessibilityHighContrastDarkAqua`, which is a distinct
    /// appearance that must still be treated as dark.
    var smIsDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
#endif

// MARK: - Card surface

extension View {
    /// The standard elevated card surface — fill, a hairline border, and a
    /// soft shadow — so cards read as distinct panels on every platform
    /// (critical on macOS, where fill ≈ window background). Shared by `SMCard`
    /// and the hand-rolled card rows so the whole app reads as one system.
    func smCardSurface(cornerRadius: CGFloat = SMTheme.cornerRadius) -> some View {
        self
            .background(SMTheme.cardFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(SMTheme.cardStroke, lineWidth: 0.75)
            )
            .shadow(color: SMTheme.cardShadow, radius: 8, x: 0, y: 2)
    }
}

// MARK: - Card

/// Standard content card: rounded rect, elevated fill, consistent padding.
struct SMCard<Content: View>: View {
    var padding: CGFloat = SMTheme.cardPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .smCardSurface()
    }
}

// MARK: - Section header

/// Section title with an optional trailing "See All"-style action.
struct SMSectionHeader: View {
    let titleKey: LocalizedStringKey
    var actionKey: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
                .font(.title3.weight(.semibold))
            Spacer()
            if let actionKey, let action {
                Button(action: action) {
                    Text(actionKey)
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
    }
}

// MARK: - Stat tile

/// Compact metric tile: icon, big rounded number, caption.
struct StatTile: View {
    let icon: String
    let iconColor: Color
    let value: String
    let labelKey: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .fitSingleLine()
            Text(labelKey)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fitSingleLine()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .smCardSurface(cornerRadius: 12)
    }
}

// MARK: - Goal ring

/// Circular daily-goal progress ring with center content.
struct GoalRing: View {
    /// 0…1 (values above 1 render as a full ring).
    let progress: Double
    var lineWidth: CGFloat = 10
    var size: CGFloat = 84
    /// The unfilled track color.
    var trackColor: Color = Color.accentColor.opacity(0.18)
    /// The filled-progress style. Defaults to the accent gradient; hero
    /// surfaces pass a solid white so the ring reads on a colored background.
    var progressStyle: AnyShapeStyle = AnyShapeStyle(SMTheme.heroGradient)

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    progressStyle,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Streak badge

/// Flame + count, tinted by whether the streak is alive today.
struct StreakBadge: View {
    let days: Int
    let activeToday: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .foregroundStyle(activeToday ? Color.orange : Color.secondary)
            Text("\(days)")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffectCapsuleCompat()
        .accessibilityLabel(Text("Day streak: \(days)"))
    }
}

// MARK: - Quick action

/// Compact vertical icon+label action used in Home's quick-actions row.
struct QuickActionButton: View {
    let icon: String
    let titleKey: LocalizedStringKey
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: Circle())
                    .foregroundStyle(tint)
                Text(titleKey)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fitSingleLine()
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hero action row

/// Prominent tappable card row: icon bubble, title, subtitle, chevron.
struct HeroActionRow: View {
    let icon: String
    let tint: Color
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(titleKey)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fitSingleLine()
                    Text(subtitleKey)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                if let badge {
                    Text(badge)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(tint.opacity(0.14), in: Capsule())
                        .foregroundStyle(tint)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(SMTheme.cardPadding)
            .smCardSurface()
            .contentShape(RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag chip

/// Small capsule label (tags, levels, states).
struct TagChip: View {
    let text: String
    var tint: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.13), in: Capsule())
            .foregroundStyle(tint)
            .fitSingleLine()
    }
}

// MARK: - Progress bar

/// Thin rounded progress bar (reading progress, session progress).
struct SMProgressBar: View {
    /// 0…1
    let progress: Double
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.15))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                    .animation(.spring(duration: 0.45), value: progress)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Empty state

/// Friendly empty state that starts the journey instead of ending it.
struct SMEmptyState: View {
    let icon: String
    let titleKey: LocalizedStringKey
    let messageKey: LocalizedStringKey
    var actionKey: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(Color.accentColor.opacity(0.85))
            Text(titleKey)
                .font(.headline)
            Text(messageKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionKey, let action {
                Button(action: action) {
                    Text(actionKey)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: 420)
        .padding(28)
    }
}

// MARK: - Celebration

/// Lightweight completion celebration: a burst of scaling symbols.
/// Honors Reduce Motion by fading instead of springing.
struct CelebrationBurst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: index.isMultiple(of: 2) ? 18 : 12))
                    .foregroundStyle(index.isMultiple(of: 3) ? Color.orange : Color.accentColor)
                    .offset(offset(for: index, radius: appeared ? 56 : 6))
                    .opacity(appeared ? 0 : 1)
            }
        }
        .onAppear {
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.8)) { appeared = true }
            } else {
                withAnimation(.spring(duration: 0.9)) { appeared = true }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func offset(for index: Int, radius: CGFloat) -> CGSize {
        let angle = (Double(index) / 8.0) * 2 * .pi
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }
}
