#if MACOS_SURFACE_CHECKS
import AppKit

// Contract checks for the macOS page/card surface pairing in `SMTheme`.
//
// The bug these exist to prevent: `windowBackgroundColor` behind
// `controlBackgroundColor` looks like the obvious "page behind card" pairing,
// but AppKit resolves BOTH to the same value — #FFFFFF in Aqua, #1E1E1E in
// Dark Aqua. Every card in the app was therefore drawn in exactly the page
// color and disappeared into it, in both appearances, with only a hairline
// border left to suggest a card was ever there.
//
// A compiler cannot catch that, and a screenshot only catches it on whichever
// appearance you happened to look at. So the pairing is asserted here against
// the *live* system colors in every appearance the app can render in — which
// also means a future macOS that collapses another pair fails loudly instead
// of silently flattening the UI again.

private struct CheckFailure: Error {
    let message: String
}

@MainActor private var checksRun = 0

/// Perceived lightness of a resolved color, 0…255.
private func luminance(_ color: NSColor) -> Double {
    guard let srgb = color.usingColorSpace(.sRGB) else { return -1 }
    return (0.299 * srgb.redComponent + 0.587 * srgb.greenComponent + 0.114 * srgb.blueComponent) * 255
}

private func describe(_ color: NSColor) -> String {
    guard let srgb = color.usingColorSpace(.sRGB) else { return "unresolvable" }
    return String(
        format: "#%02X%02X%02X",
        Int((srgb.redComponent * 255).rounded()),
        Int((srgb.greenComponent * 255).rounded()),
        Int((srgb.blueComponent * 255).rounded())
    )
}

/// The minimum step that still reads as a distinct surface. macOS's own
/// grouped pairing (`underPageBackgroundColor` behind white) is 9/255, so
/// anything at or above that is system-idiomatic; below ~6 the card stops
/// being findable without hunting for its border.
private let minimumSeparation: Double = 6

private let appearances: [NSAppearance.Name] = [
    .aqua,
    .darkAqua,
    .accessibilityHighContrastAqua,
    .accessibilityHighContrastDarkAqua,
]

private func isDark(_ appearance: NSAppearance) -> Bool {
    appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
}

/// Run `body` with `appearance` installed as the drawing appearance, so the
/// dynamic system colors inside resolve the way they would on screen.
@MainActor
private func resolving<T>(_ name: NSAppearance.Name, _ body: () -> T) -> T? {
    guard let appearance = NSAppearance(named: name) else { return nil }
    var result: T?
    appearance.performAsCurrentDrawingAppearance {
        result = body()
    }
    return result
}

@MainActor
private func runChecks() throws {

    // MARK: The pairing SMTheme actually ships
    //
    // Mirrors `SMTheme.pageBackground` / `SMTheme.cardFill`. The shell half of
    // this script pins the source to these same colors, so the two cannot
    // drift apart without one of them failing.

    for name in appearances {
        guard let appearance = NSAppearance(named: name) else {
            // A future SDK could retire an appearance; skipping is correct,
            // but it must be visible rather than quietly reducing coverage.
            print("  note: appearance \(name.rawValue) is unavailable, skipped")
            continue
        }
        let dark = isDark(appearance)

        // Everything, including the descriptions, is computed *inside* the
        // appearance block: these are dynamic colors, so reading them again
        // afterwards would re-resolve them against whatever appearance the
        // machine happens to be in and report the wrong values in the failure.
        let outcome = resolving(name) { () -> (page: String, card: String, separation: Double) in
            let page: NSColor = dark ? .windowBackgroundColor : .underPageBackgroundColor
            let card: NSColor = dark ? .underPageBackgroundColor : .controlBackgroundColor
            return (describe(page), describe(card), luminance(card) - luminance(page))
        }
        guard let outcome else { continue }

        checksRun += 1
        guard outcome.separation >= minimumSeparation else {
            throw CheckFailure(message: """
                \(name.rawValue): page \(outcome.page) and card \(outcome.card) \
                differ by \(String(format: "%.1f", outcome.separation))/255, below the \
                \(Int(minimumSeparation)) needed for a card to read as its own surface \
                (a negative value means the card is darker than the page, which reads as recessed)
                """)
        }
    }

    // MARK: The trap itself, asserted directly
    //
    // If these ever start differing, the simpler pairing becomes available and
    // `SMTheme` can drop its per-appearance branch — but until then, anyone
    // reaching for the "obvious" combination should find out here rather than
    // from a user looking at a flat screen.

    for name in appearances {
        guard let collapsed = resolving(name, {
            abs(luminance(NSColor.windowBackgroundColor) - luminance(NSColor.controlBackgroundColor)) < minimumSeparation
        }) else { continue }

        checksRun += 1
        guard collapsed else {
            throw CheckFailure(message: """
                \(name.rawValue): windowBackgroundColor and controlBackgroundColor now resolve to \
                different values. That is good news — re-check whether SMTheme still needs its \
                per-appearance pairing, simplify it if not, and update this check.
                """)
        }
    }
}

@main
private struct MacOSSurfaceChecksRunner {
    @MainActor
    static func main() {
        do {
            try runChecks()
            print("macOS surface checks passed (\(checksRun)/\(checksRun))")
        } catch let failure as CheckFailure {
            fputs("macOS surface check failed: \(failure.message)\n", stderr)
            exit(1)
        } catch {
            fputs("macOS surface checks failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
#endif
