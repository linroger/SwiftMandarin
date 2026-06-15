//
//  WorkbookGradingHistoryView.swift
//  SwiftMandarin
//
//  The Photo tab's grading history: a list of past graded workbooks, each
//  opening to the graded answers plus the original scanned photos. Kept within
//  the Photo tab per the feature design.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct WorkbookGradingHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var history = WorkbookGradingHistoryStore.shared
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if history.sessions.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(history.sessions) { session in
                            NavigationLink {
                                GradedSessionDetailView(session: session)
                            } label: {
                                SessionRow(session: session)
                            }
                        }
                        .onDelete { history.remove(at: $0) }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #endif
                }
            }
            .navigationTitle("批改历史 · Grading History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    if !history.sessions.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                #endif
            }
            .confirmationDialog("清空批改历史 · Clear grading history?",
                                isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清空 · Clear all", role: .destructive) { history.clear() }
                Button("取消 · Cancel", role: .cancel) { }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("暂无批改记录 · No graded workbooks yet", systemImage: "clock.arrow.circlepath")
        } description: {
            Text("批改作业后会自动保存到这里，包含批改结果和原始照片。\nGraded workbooks are saved here automatically, with results and the original photos.")
        } actions: {
            Button("完成 · Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: GradedSession

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(scoreColor.opacity(0.15))
                Text("\(percent)%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(scoreColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.displayScore)
                    .font(.headline)
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !session.summary.isEmpty {
                    Text(session.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if !session.allImageIDs.isEmpty {
                Label("\(session.allImageIDs.count)", systemImage: "photo")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var percent: Int {
        guard session.totalCount > 0 else { return 0 }
        return Int(round(Double(session.correctCount) / Double(session.totalCount) * 100))
    }

    private var scoreColor: Color {
        switch percent {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Session Detail

struct GradedSessionDetailView: View {
    let session: GradedSession

    @State private var bank = WorkbookQuestionBankStore.shared
    @State private var viewerPhoto: PhotoRef?

    /// Whether every question in this session is already in the review bank.
    /// Content-derived (not a one-shot flag) so it reflects items banked from
    /// the live grading screen and re-evaluates after `add()` (bank is observed).
    private var allInBank: Bool {
        !session.questions.isEmpty && session.questions.allSatisfy { bank.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scoreHeader
                if !session.summary.isEmpty {
                    Text(session.summary)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !session.allImageIDs.isEmpty { photosSection }
                addToBankButton
                ForEach(session.questions) { question in
                    SessionQuestionCard(question: question)
                }
            }
            .padding()
        }
        .navigationTitle(session.displayScore)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .fullScreenCoverCompat(item: $viewerPhoto) { ref in
            PhotoViewer(imageID: ref.id)
        }
    }

    private var scoreHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayScore)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("正确 \(session.correctCount) · 共 \(session.totalCount) 题")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(session.date.formatted(date: .long, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "graduationcap.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("原始照片 · Original photos", systemImage: "photo.stack")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(session.allImageIDs, id: \.self) { id in
                        SessionPhotoThumbnail(imageID: id) {
                            viewerPhoto = PhotoRef(id: id)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var addToBankButton: some View {
        if !session.questions.isEmpty {
            Button {
                for question in session.questions {
                    _ = bank.add(question)
                }
            } label: {
                Label(allInBank ? "已加入题库 · Added to Bank" : "全部加入题库 · Add all to Review Bank",
                      systemImage: allInBank ? "tray.full.fill" : "tray.and.arrow.down.fill")
                    .fitSingleLine()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(allInBank)
        }
    }
}

/// Identifiable wrapper so a photo ID can drive `.fullScreenCover(item:)`.
private struct PhotoRef: Identifiable { let id: String }

// MARK: - Session Question Card (read-only)

private struct SessionQuestionCard: View {
    let question: WorkbookQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: question.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(question.wasCorrect ? .green : .red)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    if !question.questionNumber.isEmpty {
                        Text("第 \(question.questionNumber) 题")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !question.question.isEmpty {
                        Text(question.question)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
                Spacer()
                if !question.spokenSentence.isEmpty {
                    Button {
                        SpeechService.speakAuto(question.spokenSentence)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Read aloud"))
                }
            }
            if !question.studentAnswer.isEmpty {
                Text("你的答案 · \(question.studentAnswer)")
                    .font(.caption)
                    .foregroundStyle(question.wasCorrect ? .green : .red)
            }
            if !question.wasCorrect, !question.correctAnswer.isEmpty {
                Text("正确答案 · \(question.correctAnswer)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if !question.explanation.isEmpty {
                Text(question.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(.background).shadow(color: .black.opacity(0.05), radius: 6, y: 3))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke((question.wasCorrect ? Color.green : Color.red).opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Photo loading

private struct SessionPhotoThumbnail: View {
    let imageID: String
    let onTap: () -> Void
    @State private var image: Image?

    var body: some View {
        Button(action: onTap) {
            Group {
                if let image {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        Color.gray.opacity(0.1)
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .frame(width: 80, height: 106)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .task(id: imageID) {
            let id = imageID
            let data = await Task.detached { WorkbookImageStore.load(id) }.value
            if let data, let img = workbookImage(from: data) {
                image = img
            }
        }
    }
}

private struct PhotoViewer: View {
    let imageID: String
    @Environment(\.dismiss) private var dismiss
    @State private var image: Image?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .task(id: imageID) {
            let id = imageID
            let data = await Task.detached { WorkbookImageStore.load(id) }.value
            if let data, let img = workbookImage(from: data) {
                image = img
            }
        }
    }
}

/// Cross-platform image decode from JPEG bytes.
private func workbookImage(from data: Data) -> Image? {
#if canImport(UIKit)
    return UIImage(data: data).map { Image(uiImage: $0) }
#elseif canImport(AppKit)
    return NSImage(data: data).map { Image(nsImage: $0) }
#else
    return nil
#endif
}

// MARK: - Cross-platform full-screen cover

private extension View {
    /// `.fullScreenCover(item:)` on iOS; `.sheet(item:)` on macOS (no
    /// full-screen cover there).
    @ViewBuilder
    func fullScreenCoverCompat<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        self.fullScreenCover(item: item, content: content)
        #else
        self.sheet(item: item, content: content)
        #endif
    }
}
