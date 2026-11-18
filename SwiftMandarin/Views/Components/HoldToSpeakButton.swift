//
//  HoldToSpeakButton.swift
//  SwiftMandarin
//
//  A press-and-hold control: `onPress` when the finger or mouse goes down,
//  `onRelease` when it comes up.
//
//  It is deliberately not a `Button`, and not `onLongPressGesture`. A long
//  press waits before it starts — the first word would be lost — and gives
//  up when the finger drifts. A zero-distance drag reports the touch the
//  instant it lands and keeps reporting it wherever it moves, and tracking it
//  with `@GestureState` means the press also ends when the system cancels
//  the gesture, which `onEnded` alone would never report.
//
//  A finger can be down on the button before the button can take a press:
//  the other speaker is still talking, or the screen has only just opened.
//  The touch is tracked all the same, and the press is delivered the moment
//  the button becomes available, if the finger is still there. Nobody should
//  be left talking to a button that looks ready and is not listening.
//
//  Holding a button is not something VoiceOver can do, so for assistive
//  technologies the same control is a toggle: activate once to start, again
//  to stop.
//

import SwiftUI

struct HoldToSpeakButton: View {
    /// What the button is doing, which decides how it looks.
    enum Phase: Equatable {
        /// Ready to be pressed.
        case ready
        /// Pressed; the microphone is opening.
        case starting
        /// The microphone is live.
        case recording
        /// Released; the transcript is being finalized or translated.
        case processing
        /// The reply to this button's turn is being spoken.
        case speaking
        /// Cannot be pressed yet.
        case unavailable
    }

    /// The words on the button, in the language of the person it is for.
    /// Each button addresses one speaker, so its text is written in that
    /// speaker's language whatever the app's interface language is.
    struct Copy: Equatable {
        let hold: String
        let listening: String
        let processing: String
        let speaking: String
        /// What an assistive technology says while the button cannot be used.
        let unavailable: String

        static let english = Copy(
            hold: "Hold for English",
            listening: "Listening…",
            processing: "Translating…",
            speaking: "Speaking…",
            unavailable: "Not available right now"
        )
        static let chinese = Copy(
            hold: "按住说中文",
            listening: "正在聆听…",
            processing: "正在翻译…",
            speaking: "正在朗读…",
            unavailable: "暂时不可用"
        )
    }

    let copy: Copy
    /// A short line under the title, such as "English → 中文".
    let caption: String
    let tint: Color
    let phase: Phase
    /// Shows the keyboard hint: holding Space presses this button.
    var showsKeyboardHint = false
    let onPress: () -> Void
    let onRelease: () -> Void

    @GestureState private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var isActive: Bool {
        phase == .recording || phase == .starting
    }

    private var title: String {
        switch phase {
        case .ready, .unavailable, .starting: return copy.hold
        case .recording: return copy.listening
        case .processing: return copy.processing
        case .speaking: return copy.speaking
        }
    }

    private var symbol: String {
        switch phase {
        case .ready, .unavailable, .starting: return "mic.fill"
        case .recording: return "waveform"
        case .processing: return "ellipsis"
        case .speaking: return "speaker.wave.2.fill"
        }
    }

    /// Red means the microphone is live, and only that.
    private var surfaceTint: Color {
        switch phase {
        case .recording: return .red
        case .starting: return tint.opacity(0.9)
        case .ready, .processing, .speaking: return tint
        case .unavailable: return .gray
        }
    }

    var body: some View {
        label
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($isPressed) { _, pressed, _ in
                        pressed = true
                    }
            )
            .onChange(of: isPressed) { _, pressed in
                // A touch that lands while the button is unavailable is kept
                // track of, not delivered; see `onChange(of: phase)` below.
                guard phase != .unavailable || !pressed else { return }
                if pressed {
                    onPress()
                } else {
                    onRelease()
                }
            }
            .onChange(of: phase) { old, new in
                // The button became usable under a finger that was already
                // down: that is a press.
                if old == .unavailable, new != .unavailable, isPressed {
                    onPress()
                }
            }
            .opacity(phase == .unavailable ? 0.45 : 1)
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: phase)
            #if os(iOS)
            // A tap on the wrist the moment the microphone is really live, so
            // the speaker knows when to start without looking.
            .sensoryFeedback(.impact(weight: .medium), trigger: phase) { _, new in
                new == .recording
            }
            #endif
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: copy.hold))
            .accessibilityValue(Text(verbatim: accessibilityState))
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(.startsMediaSession)
            .accessibilityAction {
                guard phase != .unavailable else { return }
                if isActive {
                    onRelease()
                } else {
                    onPress()
                }
            }
    }

    /// What the button is doing, for assistive technologies. Empty while it
    /// simply waits to be pressed.
    private var accessibilityState: String {
        switch phase {
        case .ready: return ""
        case .unavailable: return copy.unavailable
        case .starting, .recording: return copy.listening
        case .processing: return copy.processing
        case .speaking: return copy.speaking
        }
    }

    /// How to use the button without holding it. VoiceOver activates with a
    /// double tap on a touch screen and with a key press on a Mac.
    private var accessibilityHint: Text {
        #if os(macOS)
        Text("Press to start speaking, and press again to stop.")
        #else
        Text("Double-tap to start speaking, and double-tap again to stop.")
        #endif
    }

    private var label: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .symbolEffect(.variableColor.iterative, isActive: phase == .recording && !reduceMotion)
                .symbolEffect(.pulse, isActive: phase == .processing && !reduceMotion)
                .frame(height: 30)
            Text(verbatim: title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .fitSingleLine(0.7)
            HStack(spacing: 6) {
                Text(verbatim: caption)
                    .font(.caption)
                    .opacity(0.85)
                if showsKeyboardHint {
                    Text("Space")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .accessibilityHidden(true)
                }
            }
            // The same height with or without the key cap, so the two
            // buttons' icons and titles line up.
            .frame(minHeight: 20)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(surfaceTint.gradient)
                .overlay {
                    // A ring that breathes while the microphone is live.
                    if phase == .recording {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.white.opacity(pulse ? 0.15 : 0.7), lineWidth: 3)
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: pulse
                            )
                            .onAppear { pulse = true }
                            .onDisappear { pulse = false }
                    }
                }
                .shadow(color: surfaceTint.opacity(isActive ? 0.45 : 0.25), radius: isActive ? 14 : 8, y: 4)
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        HoldToSpeakButton(
            copy: .english,
            caption: "English → 中文",
            tint: .indigo,
            phase: .ready,
            showsKeyboardHint: true,
            onPress: {},
            onRelease: {}
        )
        HoldToSpeakButton(
            copy: .chinese,
            caption: "中文 → English",
            tint: Color(red: 0.0, green: 0.47, blue: 0.55),
            phase: .recording,
            onPress: {},
            onRelease: {}
        )
    }
    .padding()
}
