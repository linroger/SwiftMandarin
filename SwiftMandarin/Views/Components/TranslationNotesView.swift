//
//  TranslationNotesView.swift
//  SwiftMandarin
//
//  Renders the study notes that arrive in the same structured response as an
//  AI translation: one short explanation of what made the passage tricky, and
//  the handful of terms a learner would have needed to look up.
//
//  The notes are deliberately optional — the prompt tells the model to return
//  nothing when a passage is easy — so this view renders nothing at all rather
//  than an empty "no notes" placeholder.
//

import SwiftUI

struct TranslationNotesView: View {
    let result: AITranslationResult
    /// Called when the learner saves a term; `nil` hides the save affordance
    /// on surfaces that have no vocabulary store in scope.
    var onSave: ((AITranslationKeyTerm) -> Void)?
    /// Whether a term is already in the vocabulary book, so the row can show
    /// that instead of offering a duplicate save.
    var isSaved: ((AITranslationKeyTerm) -> Bool)?

    @State private var isExpanded = true

    var body: some View {
        if result.hasNotes {
            VStack(alignment: .leading, spacing: 12) {
                header

                if isExpanded {
                    if !result.explanation.isEmpty {
                        Text(result.explanation)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }

                    if !result.keyTerms.isEmpty {
                        if !result.explanation.isEmpty {
                            Divider()
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(result.keyTerms) { term in
                                keyTermRow(term)
                                if term.id != result.keyTerms.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SMTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous)
                    .fill(Color.purple.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous)
                    .stroke(Color.purple.opacity(0.16), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
        }
    }

    private var header: some View {
        HStack {
            Label("Translation Notes", systemImage: "lightbulb.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.purple)
            Spacer()
            if !result.keyTerms.isEmpty {
                Text("\(result.keyTerms.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.14)))
                    .accessibilityLabel(
                        Text("\(result.keyTerms.count) key terms")
                    )
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? Text("Hide translation notes") : Text("Show translation notes"))
        }
    }

    private func keyTermRow(_ term: AITranslationKeyTerm) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(term.term)
                        .font(.body.weight(.medium))
                        .textSelection(.enabled)
                    if !term.reading.isEmpty {
                        Text(term.reading)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(term.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !term.note.isEmpty {
                    Text(term.note)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onSave {
                let saved = isSaved?(term) ?? false
                Button {
                    onSave(term)
                } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .font(.body)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .disabled(saved)
                .accessibilityLabel(
                    saved
                        ? Text("\(term.term) is already saved")
                        : Text("Save \(term.term) to vocabulary")
                )
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        TranslationNotesView(
            result: AITranslationResult(
                translation: "He finally came clean about the whole thing.",
                explanation: "坦白 is not \"flat and white\" — it is a set verb meaning to confess, and Chinese "
                    + "puts 终于 before the verb where English puts \"finally\" after the subject.",
                keyTerms: [
                    AITranslationKeyTerm(
                        term: "坦白",
                        reading: "tǎnbái",
                        meaning: "to confess, to come clean",
                        note: "Used for admitting something you were hiding, not for ordinary honesty."
                    ),
                    AITranslationKeyTerm(
                        term: "来龙去脉",
                        reading: "láilóng qùmài",
                        meaning: "the whole story, the ins and outs",
                        note: "A chengyu; sounds bookish in casual speech."
                    ),
                ]
            ),
            onSave: { _ in },
            isSaved: { _ in false }
        )
        .padding()
    }
}
