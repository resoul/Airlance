import Foundation
import Observers
import os
import Protocol
import ServerConnection

enum AutomationError: Error {
    case refused
    case notConnected
}

@MainActor
final class AccountScheduled {
    private static let logger = Logger(subsystem: "Airlance", category: "Scheduled")

    private let connection: ServerConnection
    private weak var history: ChatHistoryStore?

    init(connection: ServerConnection, history: ChatHistoryStore) {
        self.connection = connection
        self.history = history
    }

    func refresh() {
        Task {
            await perform(.scheduledGet)
        }
    }

    func add(_ message: ScheduledMessage, chatID: String) {
        let rules = ScheduleRepeat.allCases
        let request = ScheduledAddRequest(
            clientID: message.id,
            chatID: chatID,
            text: message.text,
            sendAtUnixMs: Int64(message.date.timeIntervalSince1970 * 1000),
            repeatRule: Int32(rules.firstIndex(of: message.repeatRule) ?? 0),
            timezone: TimeZone.current.identifier
        )
        Task {
            if await !perform(.scheduledAdd(request)) {
                history?.markScheduledFailed(message.id, in: chatID)
            }
        }
    }

    func cancel(_ id: String) {
        Task {
            await perform(.scheduledCancel(id: id))
        }
    }

    func sendNow(_ id: String) {
        Task {
            await perform(.scheduledSendNow(id: id))
        }
    }

    @discardableResult
    private func perform(_ request: AutomationWireMessage) async -> Bool {
        do {
            guard case .automation(.scheduled(let items)) = try await connection.request(.automation(request)) else {
                return false
            }

            history?.setServerScheduled(items)

            return true
        } catch {
            Self.logger.debug("A scheduled request failed: \(String(describing: error))")

            return false
        }
    }
}

@MainActor
final class AgentsStore {
    private(set) var agents: [ServerAgent] = []
    var editingID: String?
    private let observers = ObserverList<[ServerAgent]>()
    private var connection: ServerConnection?

    func attach(_ connection: ServerConnection) {
        self.connection = connection
    }

    func observe(_ onChange: @escaping @MainActor @Sendable ([ServerAgent]) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(agents)

        return token
    }

    func agent(_ id: String?) -> ServerAgent? {
        agents.first { agent in
            agent.id == id
        }
    }

    func refresh() {
        Task {
            _ = try? await apply(.agentsGet)
        }
    }

    @discardableResult
    func save(_ agent: ServerAgent, rotateWebhook: Bool = false) async throws -> String {
        try await apply(.agentSave(agent, rotateWebhook: rotateWebhook))
    }

    func delete(_ id: String) async throws {
        try await apply(.agentDelete(id: id))
    }

    func runs(of id: String) async throws -> [ServerAgentRun] {
        guard let connection else {
            throw AutomationError.notConnected
        }

        let reply = try await connection.request(.automation(.agentRunsGet(id: id)))
        guard case .automation(.agentRuns(let runs)) = reply else {
            throw AutomationError.refused
        }

        return runs
    }

    @discardableResult
    private func apply(_ request: AutomationWireMessage) async throws -> String {
        guard let connection else {
            throw AutomationError.notConnected
        }

        guard case .automation(.agents(let next, let token)) = try await connection.request(.automation(request)) else {
            throw AutomationError.refused
        }

        agents = next
        observers.notify(next)

        return token
    }
}
