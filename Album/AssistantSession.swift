import Foundation
import Observation
import CoreLocation

@MainActor @Observable final class AssistantSession {
    let store: AlbumStore
    var messages: [AssistantMessage] = []
    var preferences: [String] = []
    var webSearch = false
    var isLoading = false
    var lastError: String?
    var lastUserText = ""
    private(set) var actionRevision = 0
    private var request: Task<Void, Never>?
    private var requestToken = UUID()
    private var actions: [String: AssistantActions] = [:]
    private let service: AssistantService
    private let locationProvider = AssistantLocationProvider()
    private let historyFile: URL

    init(store: AlbumStore, service: AssistantService? = nil) {
        self.store = store
        self.service = service ?? AssistantService()
        let participant = CollectionIdentity.participantID()
        let safeAlbum = store.data.albumID.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let safeParticipant = participant.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        self.historyFile = store.root.appendingPathComponent("assistant-\(safeAlbum)-\(safeParticipant).json")
        load()
    }

    var canSend: Bool { !isLoading }

    func send(_ text: String, location: CLLocationCoordinate2D? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }
        lastUserText = trimmed
        lastError = nil
        messages.append(AssistantMessage(role: "user", text: String(trimmed.prefix(8_000))))
        isLoading = true
        persist()
        let requestHistory = messages
        let currentPreferences = preferences
        let wantsWeb = webSearch
        let action = AssistantActions(store: store)
        let token = UUID()
        requestToken = token
        request = Task { [weak self] in
            guard let self else { return }
            do {
                let reply = try await self.service.send(store: self.store, message: trimmed, history: requestHistory, preferences: currentPreferences, location: location, webSearch: wantsWeb)
                guard !Task.isCancelled, self.requestToken == token else { return }
                let assistantMessage = AssistantMessage(role: "assistant", text: reply.answer, reply: reply)
                self.messages.append(assistantMessage)
                self.actions[assistantMessage.id] = action
                self.lastError = nil
                self.persist()
            } catch is CancellationError {
                guard self.requestToken == token else { return }
                self.lastError = "Anfrage abgebrochen."
            } catch {
                guard self.requestToken == token else { return }
                self.lastError = error.localizedDescription
            }
            guard self.requestToken == token else { return }
            self.isLoading = false
            self.request = nil
        }
    }

    func retry() {
        guard !lastUserText.isEmpty, !isLoading else { return }
        // Keep the conversation visible and send a fresh request with the same text.
        send(lastUserText)
    }

    func cancel() {
        requestToken = UUID()
        request?.cancel()
        request = nil
        isLoading = false
        lastError = "Anfrage abgebrochen."
    }

    func clear() {
        cancel()
        messages.removeAll()
        preferences.removeAll()
        actions.removeAll()
        lastUserText = ""
        lastError = nil
        persist()
    }

    func remember(_ preference: String) {
        let value = preference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !preferences.contains(value) else { return }
        preferences.append(value); persist()
    }

    func forget(_ preference: String) {
        preferences.removeAll { $0 == preference }; persist()
    }

    func useLocation() async -> CLLocationCoordinate2D? { await locationProvider.request() }

    func applyPlan(_ plan: [AssistantDay], messageID: String) async throws {
        guard let action = actions[messageID] else { throw AssistantActions.ActionError.noUndo }
        try await action.refreshBeforeApply(to: store)
        try action.apply(plan, to: store)
        actionRevision += 1
    }

    func canApply(messageID: String) -> Bool {
        actions[messageID] != nil
    }

    func canUndo(messageID: String) -> Bool { _ = actionRevision; return actions[messageID]?.canUndo == true }

    func undo(messageID: String) throws {
        guard let action = actions[messageID] else { throw AssistantActions.ActionError.noUndo }
        try action.undo(in: store)
        actionRevision += 1
    }

    private struct Envelope: Codable {
        var messages: [AssistantMessage]
        var preferences: [String]
        var actionSnapshots: [String: AssistantActions.Snapshot]

        init(messages: [AssistantMessage], preferences: [String], actionSnapshots: [String: AssistantActions.Snapshot]) {
            self.messages = messages
            self.preferences = preferences
            self.actionSnapshots = actionSnapshots
        }

        private enum CodingKeys: String, CodingKey { case messages, preferences, actionSnapshots }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            messages = try container.decode([AssistantMessage].self, forKey: .messages)
            preferences = try container.decode([String].self, forKey: .preferences)
            actionSnapshots = try container.decodeIfPresent([String: AssistantActions.Snapshot].self, forKey: .actionSnapshots) ?? [:]
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyFile), let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return }
        messages = Array(envelope.messages.suffix(100)); preferences = Array(envelope.preferences.prefix(20))
        for message in messages {
            if let reply = message.reply {
                if !reply.plan.isEmpty, let snapshot = envelope.actionSnapshots[message.id] {
                    actions[message.id] = AssistantActions(store: store, snapshot: snapshot)
                }
            }
        }
    }

    private func persist() {
        do {
            let retainedMessages = Array(messages.suffix(100))
            let retainedIDs = Set(retainedMessages.map(\.id))
            let snapshots = actions.reduce(into: [String: AssistantActions.Snapshot]()) { result, entry in
                guard retainedIDs.contains(entry.key) else { return }
                result[entry.key] = entry.value.snapshot
            }
            try JSONEncoder().encode(Envelope(messages: retainedMessages, preferences: Array(preferences.prefix(20)), actionSnapshots: snapshots)).write(to: historyFile, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {
            // Chat history is an enhancement; a full disk must never break the trip UI.
        }
    }
}
