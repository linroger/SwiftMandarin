//
//  AIAudioStatusBanner.swift
//  SwiftMandarin
//
//  App-wide, actionable feedback when MiniMax speech fails or falls back.
//

import SwiftUI

struct AIAudioStatusBanner: View {
    @State private var runtime = AIAudioRuntimeState.shared

    private var isVisible: Bool {
        runtime.noticeMessage != nil
    }

    var body: some View {
        if isVisible, let message = runtime.noticeMessage {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: runtime.noticeIsError
                      ? "exclamationmark.triangle.fill"
                      : "speaker.wave.2.fill")
                    .foregroundStyle(runtime.noticeIsError ? .red : .orange)

                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button {
                    runtime.dismissNotice()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss AI Audio message")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 680)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .accessibilityElement(children: .contain)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(100)
        }
    }
}
