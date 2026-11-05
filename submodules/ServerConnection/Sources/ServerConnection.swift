import Foundation
import Protocol
import WireAuth

public enum ServerConnectionError: Error, Sendable, Equatable {
    case unauthorized
    case disconnected
    case timedOut
    case invalidResponse
    case refused(code: Int32)
}

public struct ServerUpdates: Sendable {
    public let latestSeq: UInt64
    public let stream: AsyncStream<ProtocolEnvelope>
}

public actor ServerConnection {
    public typealias TokenProvider = @Sendable () async throws -> String

    private struct SocketTransport: WireAuthTransport {
        let socket: URLSessionWebSocketTask

        func sendAndReceive(_ packet: Data) async throws -> Data {
            try await socket.send(.data(packet))
            guard case .data(let reply) = try await socket.receive() else {
                throw ServerConnectionError.invalidResponse
            }

            return reply
        }
    }

    private static let requestTimeout: Duration = .seconds(15)
    private static let unauthorizedCode: Int32 = 401
    private static let conflictCode: Int32 = 409
    private static let unavailableCode: Int32 = 503

    private let url: URL
    private let pins: [WireAuthPin]
    private let token: TokenProvider
    private let codec = ProtocolCodec()
    private var socket: URLSessionWebSocketTask?
    private var channel: WireAuthChannel?
    private var connecting: Task<Void, any Error>?
    private var sending: Task<Void, Never>?
    private var nextRequestID: UInt64 = 0
    private var pending: [UInt64: CheckedContinuation<ProtocolMessage, any Error>] = [:]
    private var updates: AsyncStream<ProtocolEnvelope>.Continuation?

    public init(url: URL, pins: [WireAuthPin], token: @escaping TokenProvider) {
        self.url = url
        self.pins = pins
        self.token = token
    }

    public func request(_ message: ProtocolMessage) async throws -> ProtocolMessage {
        do {
            return try await attempt(message)
        } catch ServerConnectionError.disconnected {
            return try await attempt(message)
        }
    }

    public func subscribe(after seq: UInt64) async throws -> ServerUpdates {
        try await connect()
        let (stream, continuation) = AsyncStream.makeStream(of: ProtocolEnvelope.self)
        finishUpdates()
        updates = continuation
        do {
            let reply = try await attempt(.updatesSubscribe(afterSeq: seq))

            return ServerUpdates(latestSeq: try latestSeq(from: reply), stream: stream)
        } catch {
            finishUpdates()
            throw error
        }
    }

    public func close() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        channel = nil
        failPending(ServerConnectionError.disconnected)
        finishUpdates()
    }

    private func latestSeq(from reply: ProtocolMessage) throws -> UInt64 {
        switch reply {
        case .updatesSubscribed(let latestSeq):
            return latestSeq
        case .error(let error) where error.code == Self.conflictCode:
            close()
            throw ServerConnectionError.disconnected
        case .error(let error):
            throw ServerConnectionError.refused(code: error.code)
        default:
            throw ServerConnectionError.invalidResponse
        }
    }

    private func finishUpdates() {
        updates?.finish()
        updates = nil
    }

    private func attempt(_ message: ProtocolMessage) async throws -> ProtocolMessage {
        try await connect()
        guard let socket else {
            throw ServerConnectionError.disconnected
        }

        nextRequestID += 1
        let id = nextRequestID
        let packet = try seal(ProtocolEnvelope(requestID: id, message: message))

        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            Task {
                try? await Task.sleep(for: Self.requestTimeout)
                self.fail(id, with: ServerConnectionError.timedOut)
            }
            enqueue(packet, on: socket, requestID: id)
        }
    }

    private func enqueue(_ packet: Data, on socket: URLSessionWebSocketTask, requestID: UInt64) {
        let previous = sending
        sending = Task {
            await previous?.value
            do {
                try await socket.send(.data(packet))
            } catch {
                self.fail(requestID, with: ServerConnectionError.disconnected)
            }
        }
    }

    private func connect() async throws {
        if socket != nil {
            return
        }

        if let connecting {
            try await connecting.value

            return
        }

        let task = Task {
            try await self.open()
        }
        connecting = task
        defer {
            connecting = nil
        }

        try await task.value
    }

    private func open() async throws {
        let accessToken = try await token()
        let socket = URLSession.shared.webSocketTask(with: url)
        socket.resume()
        do {
            var channel = try await WireAuthHandshake.establish(pins: pins, transport: SocketTransport(socket: socket))
            try await authenticate(accessToken, on: socket, channel: &channel)
            self.socket = socket
            self.channel = channel
            sending = nil
        } catch {
            socket.cancel(with: .goingAway, reason: nil)
            throw Self.connectionError(error)
        }

        Task {
            await read(socket)
        }
    }

    private func authenticate(
        _ accessToken: String,
        on socket: URLSessionWebSocketTask,
        channel: inout WireAuthChannel
    ) async throws {
        let envelope = ProtocolEnvelope(message: .authenticate(token: accessToken))
        let sealed = try channel.seal(try codec.encode(envelope))
        try await socket.send(.data(sealed))
        guard case .data(let reply) = try await socket.receive() else {
            throw ServerConnectionError.invalidResponse
        }

        switch try codec.decode(try channel.open(reply)).message {
        case .authenticated:
            return
        case .error(let error) where error.code == Self.unauthorizedCode:
            throw ServerConnectionError.unauthorized
        case .error(let error) where error.code == Self.unavailableCode:
            throw ServerConnectionError.disconnected
        default:
            throw ServerConnectionError.invalidResponse
        }
    }

    private func seal(_ envelope: ProtocolEnvelope) throws -> Data {
        guard var channel else {
            throw ServerConnectionError.disconnected
        }

        let sealed = try channel.seal(try codec.encode(envelope))
        self.channel = channel

        return sealed
    }

    private func read(_ socket: URLSessionWebSocketTask) async {
        do {
            while true {
                let received = try await socket.receive()
                if case .data(let data) = received {
                    try handle(data)
                }
            }
        } catch ServerConnectionError.invalidResponse {
            disconnect(socket, with: ServerConnectionError.invalidResponse)
        } catch {
            disconnect(socket, with: ServerConnectionError.disconnected)
        }
    }

    private func handle(_ data: Data) throws {
        guard var channel else {
            throw ServerConnectionError.disconnected
        }

        let envelope: ProtocolEnvelope
        do {
            envelope = try codec.decode(try channel.open(data))
        } catch {
            throw ServerConnectionError.invalidResponse
        }

        self.channel = channel
        if envelope.requestID == 0 {
            updates?.yield(envelope)

            return
        }

        pending.removeValue(forKey: envelope.requestID)?.resume(returning: envelope.message)
    }

    private func disconnect(_ closed: URLSessionWebSocketTask, with error: ServerConnectionError) {
        guard socket === closed else {
            return
        }

        closed.cancel()
        socket = nil
        channel = nil
        failPending(error)
        finishUpdates()
    }

    private func fail(_ id: UInt64, with error: any Error) {
        pending.removeValue(forKey: id)?.resume(throwing: error)
    }

    private func failPending(_ error: any Error) {
        let waiting = pending
        pending = [:]
        for continuation in waiting.values {
            continuation.resume(throwing: error)
        }
    }

    private static func connectionError(_ error: any Error) -> any Error {
        switch error {
        case is ServerConnectionError, is WireAuthError:
            error
        case is URLError, is CancellationError:
            ServerConnectionError.disconnected
        default:
            (error as NSError).domain == NSPOSIXErrorDomain ? ServerConnectionError.disconnected : error
        }
    }
}
