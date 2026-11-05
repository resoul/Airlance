import Auth
import Connectivity
import DatabaseAPI
import Foundation
import Observers
import os
import Protocol
import ServerConnection

extension StorageKey where Value == UInt64 {
    static let syncUpdatesSeq = StorageKey("sync.updatesSeq", default: 0)
}

@MainActor
final class AccountSync {
    private static let logger = Logger(subsystem: "Airlance", category: "Sync")
    private static let firstDelay: Duration = .seconds(1)
    private static let longestDelay: Duration = .seconds(60)
    private static let noNetworkPause: Duration = .seconds(3600)
    private static let stableConnection: Duration = .seconds(30)

    var onProfile: (@MainActor (ProfileData) -> Void)?
    var onJournalLost: (@MainActor () -> Void)?
    var onSessionEnded: (@MainActor () -> Void)?

    private let connection: ServerConnection
    private let storage: any KeyValueStore
    private let status: ConnectionStatusStore
    private var seq: UInt64
    private var delay = AccountSync.firstDelay
    private var task: Task<Void, Never>?
    private var sleeper: Task<Void, Never>?
    private var networkObservation: ObservationToken?
    private var networkKind = NetworkPath.Kind.other
    private var isFollowing = false

    init(connection: ServerConnection, storage: any KeyValueStore, status: ConnectionStatusStore) {
        self.connection = connection
        self.storage = storage
        self.status = status
        seq = storage.value(for: .syncUpdatesSeq)
    }

    func start() {
        guard task == nil else {
            return
        }

        networkKind = status.network.path.kind
        networkObservation = status.network.observe { [weak self] path in
            self?.networkChanged(path)
        }
        task = Task { [weak self] in
            await self?.run()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        sleeper?.cancel()
        release()
    }

    private func release() {
        networkObservation = nil
        status.setLink(.unused)
        status.setUpdating(false)
    }

    private func networkChanged(_ path: NetworkPath) {
        guard path.kind != networkKind else {
            return
        }

        networkKind = path.kind
        sleeper?.cancel()
        if isFollowing {
            let connection = connection
            Task {
                await connection.close()
            }
        }
    }

    private func run() async {
        delay = Self.firstDelay
        status.setLink(.connecting)
        while !Task.isCancelled {
            let started = ContinuousClock.now
            if status.network.path.isConnected {
                guard await followOnce() else {
                    finish()

                    return
                }
            }

            if started.duration(to: .now) >= Self.stableConnection {
                delay = Self.firstDelay
            } else if !Task.isCancelled {
                await wait()
            }
        }
    }

    private func finish() {
        guard !Task.isCancelled else {
            return
        }

        task = nil
        release()
    }

    private func wait() async {
        let pause = status.network.path.isConnected ? delay : Self.noNetworkPause
        let sleeper = Task<Void, Never> {
            try? await Task.sleep(for: pause)
        }
        self.sleeper = sleeper
        await sleeper.value
        self.sleeper = nil
        delay = sleeper.isCancelled ? Self.firstDelay : min(delay * 2, Self.longestDelay)
    }

    private func followOnce() async -> Bool {
        do {
            try await follow()

            return true
        } catch AuthError.sessionEnded, ServerConnectionError.unauthorized {
            onSessionEnded?()

            return false
        } catch ServerConnectionError.refused(let code) where code < 500 {
            Self.logger.error("The server refused the updates: \(code)")

            return false
        } catch {
            Self.logger.debug("Updates stopped: \(String(describing: error))")

            return true
        }
    }

    private func follow() async throws {
        status.setLink(.connecting)
        let updates = try await connection.subscribe(after: seq)
        guard !Task.isCancelled else {
            return
        }

        guard updates.latestSeq >= seq else {
            try await save(0)
            await connection.close()
            onJournalLost?()

            return
        }

        isFollowing = true
        status.setUpdating(seq < updates.latestSeq)
        status.setLink(.connected)
        defer {
            isFollowing = false
            status.setUpdating(false)
            if !Task.isCancelled {
                status.setLink(.connecting)
            }
        }

        for await envelope in updates.stream {
            guard try await apply(envelope, latestSeq: updates.latestSeq) else {
                await connection.close()

                return
            }
        }
    }

    private func apply(_ envelope: ProtocolEnvelope, latestSeq: UInt64) async throws -> Bool {
        guard envelope.seq <= seq + 1 else {
            Self.logger.error("Update \(envelope.seq) arrived after \(self.seq)")

            return false
        }

        guard envelope.seq == seq + 1 else {
            return true
        }

        if case .profileData(let data) = envelope.message {
            onProfile?(data)
        }
        try await save(envelope.seq)
        if seq >= latestSeq {
            status.setUpdating(false)
        }

        return true
    }

    private func save(_ next: UInt64) async throws {
        try await storage.update(.syncUpdatesSeq) { value in
            value = next
        }
        seq = next
    }
}
