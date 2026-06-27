//
//  ConversationStore.swift
//  SwiftMandarin
//
//  Persistence for AI conversation-partner chats. Conversations are kept
//  newest-updated first and capped at the most recent 50 so the store stays
//  small; the file lives in Application Support and is written atomically off
//  the main thread with coalesced writes (same pattern as
//  WordExplanationCacheStore).
//

import Foundation
import os.log

// MARK: - Message

/// One chat bubble. Partner messages carry the learner aids the bubble
/// renders (pinyin, native-language translation); the `feedback` field lives
/// on the *learner's* message it corrects, so the orange banner renders
/// directly under the bubble it refers to.
struct ConversationMessage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let isUser: Bool
    let text: String
    /// Pinyin for a Chinese partner reply; nil for user/English messages.
    let pinyin: String?
    /// Native-language translation of a partner reply; nil for user messages.
    let translation: String?
    /// Gentle correction the AI gave for this (user) message, if any.
    var feedback: String?
    let date: Date

    init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        pinyin: String? = nil,
        translation: String? = nil,
        feedback: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.pinyin = pinyin
        self.translation = translation
        self.feedback = feedback
        self.date = date
    }

    private enum CodingKeys: String, CodingKey {
        case id, isUser, text, pinyin, translation, feedback, date
    }

    /// Tolerant decode: a payload written by another build (missing or renamed
    /// field) loads with defaults instead of discarding the whole store.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        isUser = (try? c.decode(Bool.self, forKey: .isUser)) ?? false
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        pinyin = try? c.decode(String.self, forKey: .pinyin)
        translation = try? c.decode(String.self, forKey: .translation)
        feedback = try? c.decode(String.self, forKey: .feedback)
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date(timeIntervalSince1970: 0)
    }
}

// MARK: - Conversation

/// One roleplay chat: a scenario plus its ordered messages.
struct Conversation: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let scenario: ConversationScenario
    var messages: [ConversationMessage]
    let dateStarted: Date
    var dateUpdated: Date

    init(
        id: UUID = UUID(),
        scenario: ConversationScenario,
        messages: [ConversationMessage] = [],
        dateStarted: Date = Date(),
        dateUpdated: Date = Date()
    ) {
        self.id = id
        self.scenario = scenario
        self.messages = messages
        self.dateStarted = dateStarted
        self.dateUpdated = dateUpdated
    }

    private enum CodingKeys: String, CodingKey {
        case id, scenario, messages, dateStarted, dateUpdated
    }

    /// Tolerant decode: an unknown scenario raw value (e.g. one removed in a
    /// later build) falls back to free chat rather than dropping the chat.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        scenario = (try? c.decode(ConversationScenario.self, forKey: .scenario)) ?? .freeChat
        messages = (try? c.decode([ConversationMessage].self, forKey: .messages)) ?? []
        dateStarted = (try? c.decode(Date.self, forKey: .dateStarted)) ?? Date(timeIntervalSince1970: 0)
        dateUpdated = (try? c.decode(Date.self, forKey: .dateUpdated)) ?? Date(timeIntervalSince1970: 0)
    }
}

// MARK: - Store

@Observable
@MainActor
final class ConversationStore {

    static let shared = ConversationStore()

    /// All conversations, most recently updated first.
    private(set) var conversations: [Conversation] = []

    /// Keep only this many conversations; older ones are dropped silently.
    private static let maxConversations = 50

    /// On-disk JSON store in Application Support.
    private let fileName = "conversations.json"

    /// Coalesced single-writer persistence (see WordExplanationCacheStore):
    /// a running write task drains `needsWrite` so bursts of appends collapse
    /// into at most one off-main write per throttle interval, with a trailing
    /// write guaranteed after the last mutation.
    private var writeTask: Task<Void, Never>?
    private var needsWrite = false
    private static let writeThrottle: Duration = .seconds(2)

    nonisolated private static let log = Logger(subsystem: "com.rogerlin.SwiftMandarin", category: "ConversationStore")

    private init() {
        load()
    }

    // MARK: Queries

    /// Look up a conversation by id (views hold ids, not snapshots, so bubbles
    /// always render the store's current state).
    func conversation(withID id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    // MARK: Mutations

    /// Create a new conversation for a scenario and return it.
    @discardableResult
    func startConversation(scenario: ConversationScenario) -> Conversation {
        let conversation = Conversation(scenario: scenario)
        conversations.insert(conversation, at: 0)
        trim()
        scheduleSave()
        return conversation
    }

    /// Append a message and bump the conversation to the top of the list.
    func append(message: ConversationMessage, to conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        var conversation = conversations[index]
        conversation.messages.append(message)
        conversation.dateUpdated = Date()
        conversations.remove(at: index)
        conversations.insert(conversation, at: 0)
        scheduleSave()
    }

    /// Attach the partner's correction to the learner message it refers to,
    /// so the feedback banner renders under the right bubble.
    func attachFeedback(_ feedback: String, toMessageID messageID: UUID, in conversationID: UUID) {
        guard let cIndex = conversations.firstIndex(where: { $0.id == conversationID }),
              let mIndex = conversations[cIndex].messages.firstIndex(where: { $0.id == messageID })
        else { return }
        conversations[cIndex].messages[mIndex].feedback = feedback
        scheduleSave()
    }

    /// Delete a conversation.
    func remove(_ conversation: Conversation) {
        let before = conversations.count
        conversations.removeAll { $0.id == conversation.id }
        guard conversations.count != before else { return }
        scheduleSave()
    }

    /// Drop conversations beyond the cap (list is kept newest first).
    private func trim() {
        if conversations.count > Self.maxConversations {
            conversations.removeLast(conversations.count - Self.maxConversations)
        }
    }

    // MARK: Persistence (file-backed, coalesced, off the main thread)

    private func scheduleSave() {
        needsWrite = true
        guard writeTask == nil else { return }
        writeTask = Task { [weak self] in
            guard let self else { return }
            while self.needsWrite {
                self.needsWrite = false
                let snapshot = self.conversations      // value-type COW snapshot (cheap)
                let name = self.fileName
                // Encode + write off the main actor; only Sendable values cross.
                _ = await Task.detached(priority: .utility) {
                    Self.writeToDisk(snapshot, fileName: name)
                }.value
                // Throttle: coalesce a burst of appends into one write per
                // interval; a trailing write always follows the last mutation.
                if self.needsWrite {
                    try? await Task.sleep(for: Self.writeThrottle)
                }
            }
            self.writeTask = nil
        }
    }

    nonisolated private static func writeToDisk(_ conversations: [Conversation], fileName: String) {
        guard let url = PersistentCodableStore.appSupportFileURL(fileName) else { return }
        do {
            let data = try JSONEncoder().encode(conversations)
            try data.write(to: url, options: .atomic)
        } catch {
            // Chats are convenience history; a failed write must not crash or
            // block — the next mutation retries.
            log.error("ConversationStore write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load() {
        guard let loaded = PersistentCodableStore.loadArrayFromFile([Conversation].self, fileName: fileName) else { return }
        conversations = loaded.sorted { $0.dateUpdated > $1.dateUpdated }
        trim()
    }
}
