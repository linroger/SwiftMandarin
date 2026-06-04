//
//  WorkbookGradingView.swift
//  SwiftMandarin
//
//  A tucked-away feature in the Photo tab: upload photos of a workbook (the
//  questions) and the student's written answers, send both to a vision-capable
//  LLM with an optional custom system prompt, and get back structured grading
//  (per-question correct/incorrect, the right answer, an explanation, and a
//  study vocab item for each wrong answer that can be saved to the vocab list).
//

import SwiftUI
import PhotosUI
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct WorkbookGradingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @State private var aiSettings = AIModelSettings.shared

    // Image selection
    @State private var workbookItems: [PhotosPickerItem] = []
    @State private var answerItems: [PhotosPickerItem] = []
    @State private var workbookImages: [Data] = []
    @State private var answerImages: [Data] = []
    @State private var isLoadingWorkbook = false
    @State private var isLoadingAnswers = false
    @State private var showFileImporter = false
    @State private var fileImportTarget: FileImportTarget = .workbook

    private enum FileImportTarget { case workbook, answers }

    // Grading
    @State private var customInstructions: String = ""
    @State private var isGrading = false
    @State private var result: GradingResult?
    @State private var errorMessage: String?
    @State private var savedQuestionIDs: Set<UUID> = []

    private var gradingProvider: AIProvider? {
        // Read an observable property so the view re-evaluates when settings change.
        _ = aiSettings.provider
        return AIWordExplanationService.gradingProvider()
    }

    private var canGrade: Bool {
        (!workbookImages.isEmpty || !answerImages.isEmpty) && gradingProvider != nil && !isGrading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    providerBanner
                    howItWorksNote
                    uploadSection(
                        title: "作业页面 · Workbook pages",
                        systemImage: "doc.text.image",
                        items: $workbookItems,
                        images: workbookImages,
                        isLoading: isLoadingWorkbook,
                        onAddFiles: { fileImportTarget = .workbook; showFileImporter = true },
                        onRemove: { idx in if workbookImages.indices.contains(idx) { workbookImages.remove(at: idx) } },
                        onDrop: { handleDrop($0, into: .workbook) },
                        onClear: { workbookItems = []; workbookImages = [] }
                    )
                    uploadSection(
                        title: "单独答案（可选）· Separate answers (optional)",
                        systemImage: "pencil.and.scribble",
                        items: $answerItems,
                        images: answerImages,
                        isLoading: isLoadingAnswers,
                        onAddFiles: { fileImportTarget = .answers; showFileImporter = true },
                        onRemove: { idx in if answerImages.indices.contains(idx) { answerImages.remove(at: idx) } },
                        onDrop: { handleDrop($0, into: .answers) },
                        onClear: { answerItems = []; answerImages = [] }
                    )
                    customPromptSection
                    gradeButton

                    if isGrading { gradingProgress }
                    if let error = errorMessage { errorBox(error) }
                    if let result { resultsSection(result) }
                }
                .padding()
            }
            .navigationTitle("作业批改 · Grading")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: workbookItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await addWorkbookPhotos(items) }
            }
            .onChange(of: answerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await addAnswerPhotos(items) }
            }
            // A single fileImporter routed by `fileImportTarget`. SwiftUI only
            // honors one fileImporter per view, so both buckets share this one.
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
                let target = fileImportTarget
                Task {
                    switch target {
                    case .workbook: await addWorkbookFiles(result)
                    case .answers: await addAnswerFiles(result)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var howItWorksNote: some View {
        Label {
            Text("Upload the workbook pages. If the answers are written on the pages, just add the pages — the AI detects them automatically. Add separate answer photos only if the answers are on a different sheet.")
        } icon: {
            Image(systemName: "wand.and.stars")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var providerBanner: some View {
        if let provider = gradingProvider {
            let model = aiSettings.visionModel(for: provider) ?? aiSettings.selectedModel(for: provider)
            Label("Grading with \(provider.displayName) · \(model)",
                  systemImage: "checkmark.seal")
                .font(.caption)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("No vision provider configured", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Text("Workbook grading needs a vision-capable provider with an API key — OpenAI, Claude, Qwen, Doubao, Zhipu, or Kimi. Add one in Settings → AI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
        }
    }

    private func uploadSection(
        title: String,
        systemImage: String,
        items: Binding<[PhotosPickerItem]>,
        images: [Data],
        isLoading: Bool,
        onAddFiles: @escaping () -> Void,
        onRemove: @escaping (Int) -> Void,
        onDrop: @escaping ([NSItemProvider]) -> Bool,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer()
                if !images.isEmpty {
                    Text("\(images.count) 张")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("清除", role: .destructive, action: onClear)
                        .font(.caption)
                        .buttonStyle(.borderless)
                }
            }

            if images.isEmpty {
                // Empty state doubles as a drag-and-drop target hint.
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("拖放图片到此 · Drag & drop images here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(.quaternary)
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                            thumbnail(data, onRemove: { onRemove(index) })
                        }
                    }
                }
            }

            if isLoading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("加载中…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10) {
                    // From the Photos library.
                    PhotosPicker(selection: items, maxSelectionCount: 10, matching: .images) {
                        Label("照片 · Photos", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    // From files (Files app on iOS, Finder on macOS).
                    Button(action: onAddFiles) {
                        Label("文件 · Files", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        // Accept images dragged from Photos, Finder, Safari, other apps.
        .onDrop(of: [.image], isTargeted: nil, perform: onDrop)
    }

    private func thumbnail(_ data: Data, onRemove: @escaping () -> Void) -> some View {
        Group {
            if let image = imageFromData(data) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1))
        // Tap-to-remove button + right-click/long-press context menu.
        .overlay(alignment: .topTrailing) {
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .padding(2)
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button(role: .destructive) { onRemove() } label: {
                Label("移除 · Remove", systemImage: "trash")
            }
        }
    }

    private var customPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("自定义提示（可选）· Custom instructions", systemImage: "text.bubble")
                .font(.subheadline)
            TextField(
                "e.g. This is a Grade 3 English vocabulary workbook; be strict about spelling.",
                text: $customInstructions,
                axis: .vertical
            )
            .lineLimit(2...4)
            .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }

    private var gradeButton: some View {
        Button {
            Task { await grade() }
        } label: {
            Label(isGrading ? "批改中…" : "开始批改 · Grade", systemImage: "checkmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canGrade)
    }

    private var gradingProgress: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("正在批改作业…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func errorBox(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.08)))
    }

    private func resultsSection(_ result: GradingResult) -> some View {
        VStack(spacing: 16) {
            // Score header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.score.isEmpty ? "\(result.correctCount)/\(result.questions.count)" : result.score)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("正确 \(result.correctCount) · 共 \(result.questions.count) 题")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "graduationcap.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))

            if !result.summary.isEmpty {
                Text(result.summary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(result.questions) { question in
                GradedQuestionCard(
                    question: question,
                    isSaved: savedQuestionIDs.contains(question.id),
                    onSaveVocab: { saveVocab(for: question) }
                )
            }

            // Save all wrong-answer vocab
            if result.wrongQuestions.contains(where: { $0.vocab != nil }) {
                Button {
                    saveAllWrongVocab()
                } label: {
                    Label("保存所有错题词汇到词汇本", systemImage: "bookmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Actions

    private func addWorkbookPhotos(_ items: [PhotosPickerItem]) async {
        await MainActor.run { isLoadingWorkbook = true }
        let datas = await Self.loadDownscaled(items)
        await MainActor.run {
            workbookImages.append(contentsOf: datas)
            workbookItems = []  // reset so the next pick is detected (onChange guards empty)
            isLoadingWorkbook = false
        }
    }

    private func addAnswerPhotos(_ items: [PhotosPickerItem]) async {
        await MainActor.run { isLoadingAnswers = true }
        let datas = await Self.loadDownscaled(items)
        await MainActor.run {
            answerImages.append(contentsOf: datas)
            answerItems = []
            isLoadingAnswers = false
        }
    }

    private func addWorkbookFiles(_ result: Result<[URL], Error>) async {
        guard case let .success(urls) = result, !urls.isEmpty else { return }
        await MainActor.run { isLoadingWorkbook = true }
        let datas = await Self.loadDownscaledFiles(urls)
        await MainActor.run {
            workbookImages.append(contentsOf: datas)
            isLoadingWorkbook = false
        }
    }

    private func addAnswerFiles(_ result: Result<[URL], Error>) async {
        guard case let .success(urls) = result, !urls.isEmpty else { return }
        await MainActor.run { isLoadingAnswers = true }
        let datas = await Self.loadDownscaledFiles(urls)
        await MainActor.run {
            answerImages.append(contentsOf: datas)
            isLoadingAnswers = false
        }
    }

    /// Load each picked Photos item to Data and downscale it for the request.
    private static func loadDownscaled(_ items: [PhotosPickerItem]) async -> [Data] {
        var datas: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                datas.append(downscaledJPEG(data))
            }
        }
        return datas
    }

    /// Load each user-selected file URL to Data (security-scoped) and downscale.
    private static func loadDownscaledFiles(_ urls: [URL]) async -> [Data] {
        var datas: [Data] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                datas.append(downscaledJPEG(data))
            }
        }
        return datas
    }

    /// Handle images dragged & dropped onto a bucket (Photos, Finder, Safari, …).
    private func handleDrop(_ providers: [NSItemProvider], into target: FileImportTarget) -> Bool {
        let imageProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        guard !imageProviders.isEmpty else { return false }

        switch target {
        case .workbook: isLoadingWorkbook = true
        case .answers: isLoadingAnswers = true
        }

        Task {
            var datas: [Data] = []
            for provider in imageProviders {
                if let data = await Self.loadImageData(from: provider) {
                    datas.append(downscaledJPEG(data))
                }
            }
            await MainActor.run {
                switch target {
                case .workbook:
                    workbookImages.append(contentsOf: datas)
                    isLoadingWorkbook = false
                case .answers:
                    answerImages.append(contentsOf: datas)
                    isLoadingAnswers = false
                }
            }
        }
        return true
    }

    private static func loadImageData(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func grade() async {
        await MainActor.run {
            isGrading = true
            errorMessage = nil
            result = nil
            savedQuestionIDs = []
        }
        do {
            let graded = try await AIWordExplanationService.shared.gradeWorkbook(
                workbookImages: workbookImages,
                answerImages: answerImages,
                customInstructions: customInstructions.isEmpty ? nil : customInstructions
            )
            await MainActor.run {
                result = graded
                isGrading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isGrading = false
            }
        }
    }

    private func saveVocab(for question: GradedQuestion) {
        guard let vocab = question.vocab else { return }
        if saveVocabItem(vocab) {
            savedQuestionIDs.insert(question.id)
        }
    }

    private func saveAllWrongVocab() {
        guard let result else { return }
        for question in result.wrongQuestions {
            guard let vocab = question.vocab else { continue }
            if saveVocabItem(vocab) {
                savedQuestionIDs.insert(question.id)
            }
        }
    }

    /// Save a vocab item to the (Chinese-keyed) vocabulary store. Returns true
    /// if it was added or already present.
    @discardableResult
    private func saveVocabItem(_ item: ExtractedVocabItem) -> Bool {
        let termIsChinese = item.term.contains { $0.isChineseCharacter }
        let chinese = termIsChinese ? item.term : item.meaning
        let pinyin = termIsChinese
            ? (item.reading.isEmpty ? PinyinConverter.convert(item.term) : item.reading)
            : PinyinConverter.convert(item.meaning)
        let definition = termIsChinese ? item.meaning : item.term

        let trimmed = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.contains(where: { $0.isChineseCharacter }) else { return false }

        if !savedTermsStore.contains(chinese: trimmed) {
            savedTermsStore.add(SavedTerm(
                chinese: trimmed,
                pinyin: pinyin,
                definition: definition,
                partOfSpeech: "phrase"
            ))
        }
        return true
    }
}

// MARK: - Graded Question Card

private struct GradedQuestionCard: View {
    let question: GradedQuestion
    let isSaved: Bool
    let onSaveVocab: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: question.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(question.isCorrect ? .green : .red)
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
            }

            if !question.studentAnswer.isEmpty {
                answerRow(label: "你的答案", value: question.studentAnswer,
                          color: question.isCorrect ? .green : .red)
            }
            if !question.isCorrect, !question.correctAnswer.isEmpty {
                answerRow(label: "正确答案", value: question.correctAnswer, color: .green)
            }
            if !question.explanation.isEmpty {
                Text(question.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !question.isCorrect, let vocab = question.vocab,
               !vocab.term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vocab.term).font(.subheadline).fontWeight(.medium)
                        if !vocab.reading.isEmpty {
                            Text(vocab.reading).font(.caption).foregroundStyle(.secondary)
                        }
                        if !vocab.meaning.isEmpty {
                            Text(vocab.meaning).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        onSaveVocab()
                    } label: {
                        Label(isSaved ? "已保存" : "保存", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isSaved)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke((question.isCorrect ? Color.green : Color.red).opacity(0.25), lineWidth: 1)
        )
    }

    private func answerRow(label: String, value: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Cross-platform image helpers

private func imageFromData(_ data: Data) -> Image? {
#if canImport(UIKit)
    return UIImage(data: data).map { Image(uiImage: $0) }
#elseif canImport(AppKit)
    return NSImage(data: data).map { Image(nsImage: $0) }
#else
    return nil
#endif
}

/// Downscale and JPEG-compress image data via ImageIO so multi-image requests
/// stay within reasonable payload/token limits. Applies EXIF orientation.
private func downscaledJPEG(_ data: Data, maxDimension: Int = 1536, quality: CGFloat = 0.7) -> Data {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return data }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimension,
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return data }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
        return data
    }
    CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return data }
    return output as Data
}
