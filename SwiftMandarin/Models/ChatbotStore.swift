//
//  ChatbotStore.swift
//  SwiftMandarin
//
//  AI Chat history: a list of chats, each a sequence of learner messages and
//  chunked assistant replies. File-backed with the same coalesced off-main
//  writer as ConversationStore.
//

import Foundation
import Observation
import os

nonisolated struct ChatbotMessage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let isUser: Bool
    /// The learner's message, or the assistant's reply in the learning language.
    let text: String
    /// The reply in the learner's own language (assistant only).
    let translation: String?
    /// The reply split into semantic chunks (assistant only).
    let chunks: [ChatbotChunk]?
    /// Whether the chunks came from the model (with meanings) or from local
    /// segmentation after the model's chunks were unusable (readings only).
    let chunksFromModel: Bool
    /// The language the reply was written in, so a chat started before the
    /// learner switched direction still renders and speaks correctly.
    let replyIsChinese: Bool
    let date: Date

    init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        translation: String? = nil,
        chunks: [ChatbotChunk]? = nil,
        chunksFromModel: Bool = false,
        replyIsChinese: Bool = false,
        date: Date = Date()
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.translation = translation
        self.chunks = chunks
        self.chunksFromModel = chunksFromModel
        self.replyIsChinese = replyIsChinese
        self.date = date
    }
}

nonisolated struct ChatbotThread: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var messages: [ChatbotMessage]
    let dateStarted: Date
    var dateUpdated: Date

    init(id: UUID = UUID(), messages: [ChatbotMessage] = [], dateStarted: Date = Date(), dateUpdated: Date = Date()) {
        self.id = id
        self.messages = messages
        self.dateStarted = dateStarted
        self.dateUpdated = dateUpdated
    }

    /// The first thing the learner asked, as the chat's name in History.
    var title: String {
        let first = messages.first(where: \.isUser)?.text ?? ""
        let line = first.split(whereSeparator: \.isNewline).first.map(String.init) ?? first
        return line.count > 60 ? String(line.prefix(60)) + "…" : line
    }
}

@Observable
@MainActor
final class ChatbotStore {

    static let shared = ChatbotStore()

    /// All chats, most recently updated first.
    private(set) var threads: [ChatbotThread] = []

    /// The chat on screen. `nil` means a fresh, not-yet-started chat — a chat
    /// is only stored once it has a message, so History never fills with
    /// empty entries.
    var currentThreadID: UUID?

    /// Chats with a reply on its way. Kept here rather than in the view
    /// because the request outlives the screen: leaving AI Chat and coming
    /// back, or switching chats, must still show the typing indicator and
    /// still block a second request that would answer out of order.
    private(set) var pendingThreadIDs: Set<UUID> = []

    /// The last failed request per chat, for the Retry banner. Not persisted.
    private(set) var replyErrors: [UUID: String] = [:]

    private static let maxThreads = 50
    private let fileName = "chatbot-threads.json"

    private var writeTask: Task<Void, Never>?
    private var needsWrite = false
    private static let writeThrottle: Duration = .seconds(1)

    nonisolated private static let log = Logger(subsystem: "com.rogerlin.SwiftMandarin", category: "ChatbotStore")

    private init() {
        load()
        currentThreadID = threads.first?.id
    }

    var currentThread: ChatbotThread? {
        guard let currentThreadID else { return nil }
        return threads.first { $0.id == currentThreadID }
    }

    func thread(withID id: UUID) -> ChatbotThread? {
        threads.first { $0.id == id }
    }

    // MARK: Mutations

    /// Leave the current chat in History and start a blank one.
    func startNewThread() {
        currentThreadID = nil
    }

    /// Append a message to a chat, creating the chat on its first message.
    /// Returns the chat's id, which a caller keeps so a reply that arrives
    /// after the learner switched chats still lands in the right one.
    @discardableResult
    func append(_ message: ChatbotMessage, to threadID: UUID?) -> UUID {
        if let threadID, let index = threads.firstIndex(where: { $0.id == threadID }) {
            var thread = threads[index]
            thread.messages.append(message)
            thread.dateUpdated = Date()
            threads.remove(at: index)
            threads.insert(thread, at: 0)
            scheduleSave()
            return thread.id
        }
        let thread = ChatbotThread(id: threadID ?? UUID(), messages: [message])
        threads.insert(thread, at: 0)
        if threads.count > Self.maxThreads {
            threads.removeLast(threads.count - Self.maxThreads)
        }
        scheduleSave()
        return thread.id
    }

    /// Append the assistant's reply to an existing chat. Unlike `append`, it
    /// never creates one: a reply that arrives after its chat was deleted is
    /// dropped instead of bringing the chat back as an answer with no question.
    func appendReply(_ message: ChatbotMessage, to threadID: UUID) {
        guard threads.contains(where: { $0.id == threadID }) else { return }
        append(message, to: threadID)
    }

    // MARK: Request state

    func isAwaitingReply(in threadID: UUID?) -> Bool {
        guard let threadID else { return false }
        return pendingThreadIDs.contains(threadID)
    }

    /// Mark a chat as waiting. Returns `false` when it already is, so the
    /// caller never starts a second request for the same chat.
    func beginReply(in threadID: UUID) -> Bool {
        guard !pendingThreadIDs.contains(threadID) else { return false }
        pendingThreadIDs.insert(threadID)
        replyErrors[threadID] = nil
        return true
    }

    func finishReply(in threadID: UUID, error: String? = nil) {
        pendingThreadIDs.remove(threadID)
        if let error, threads.contains(where: { $0.id == threadID }) {
            replyErrors[threadID] = error
        }
    }

    func clearError(in threadID: UUID) {
        replyErrors[threadID] = nil
    }

    func remove(_ thread: ChatbotThread) {
        replyErrors[thread.id] = nil
        threads.removeAll { $0.id == thread.id }
        if currentThreadID == thread.id {
            currentThreadID = nil
        }
        scheduleSave()
    }

    func removeAll() {
        replyErrors.removeAll()
        threads.removeAll()
        currentThreadID = nil
        scheduleSave()
    }

    // MARK: Persistence (file-backed, coalesced, off the main thread)

    private func scheduleSave() {
        needsWrite = true
        guard writeTask == nil else { return }
        writeTask = Task { [weak self] in
            guard let self else { return }
            while self.needsWrite {
                self.needsWrite = false
                let snapshot = self.threads
                let name = self.fileName
                _ = await Task.detached(priority: .utility) {
                    Self.writeToDisk(snapshot, fileName: name)
                }.value
                if self.needsWrite {
                    try? await Task.sleep(for: Self.writeThrottle)
                }
            }
            self.writeTask = nil
        }
    }

    nonisolated private static func writeToDisk(_ threads: [ChatbotThread], fileName: String) {
        guard let url = PersistentCodableStore.appSupportFileURL(fileName) else { return }
        do {
            let data = try JSONEncoder().encode(threads)
            try data.write(to: url, options: .atomic)
        } catch {
            log.error("ChatbotStore write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load() {
        guard let loaded = PersistentCodableStore.loadArrayFromFile([ChatbotThread].self, fileName: fileName) else { return }
        threads = loaded.sorted { $0.dateUpdated > $1.dateUpdated }
        if threads.count > Self.maxThreads {
            threads.removeLast(threads.count - Self.maxThreads)
        }
    }
}
