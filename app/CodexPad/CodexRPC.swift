import Combine
import Foundation

enum RPCInbound: Sendable {
    case notification(method: String, params: JSONValue)
    case request(id: JSONValue, method: String, params: JSONValue)
}

struct CodexRPCError: LocalizedError, Equatable, Sendable {
    let code: Int?
    let message: String

    var errorDescription: String? { message }
    var isRetryable: Bool { code == -32001 }
}

@MainActor
final class CodexRPCClient: ObservableObject {
    enum State: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    @Published private(set) var state: State = .disconnected

    var inboundHandler: ((RPCInbound) -> Void)?
    var connectionFailureHandler: ((String) -> Void)?
    private(set) var connectionID = UUID()

    private let endpoint: URL
    private var session: URLSession?
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Error>?
    private var heartbeatTask: Task<Void, Never>?
    private var heartbeatDeadlineTask: Task<Void, Never>?
    private var pendingPingID: UUID?
    private var nextRequestID = 1
    private var pending: [Int: CheckedContinuation<JSONValue, Error>] = [:]

    init(endpoint: URL = URL(string: "ws://127.0.0.1:4500")!) {
        self.endpoint = endpoint
    }

    func connect() async throws {
        guard state != .connected else { return }
        if let connectionTask {
            return try await connectionTask.value
        }
        disconnect()
        let generation = connectionID
        let task = Task { [weak self] in
            guard let self else { throw CancellationError() }
            try await self.openConnection(generation: generation)
        }
        connectionTask = task
        defer {
            if connectionID == generation { connectionTask = nil }
        }
        try await task.value
    }

    private func openConnection(generation: UUID) async throws {
        try Task.checkCancellation()
        guard connectionID == generation else { throw CancellationError() }
        state = .connecting

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        let socket = session.webSocketTask(with: endpoint)
        self.session = session
        self.socket = socket
        socket.resume()

        receiveTask = Task { [weak self, weak socket] in
            guard let self, let socket else { return }
            await self.receiveMessages(from: socket, generation: generation)
        }

        // A live WebSocket does not impose a deadline on its JSON-RPC replies.
        let handshakeDeadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            self?.failConnection(
                CodexRPCError(code: nil, message: "Codex engine handshake timed out"),
                generation: generation
            )
        }
        defer { handshakeDeadline.cancel() }

        do {
            _ = try await request(
                method: "initialize",
                params: .object([
                    "clientInfo": .object([
                        "name": .string("codexpad"),
                        "title": .string("CodexPad for iPadOS"),
                        "version": .string(Bundle.main.releaseVersion)
                    ]),
                    "capabilities": .object([
                        "experimentalApi": .bool(true)
                    ])
                ])
            )
            try requireCurrentConnection(socket, generation: generation)
            try await notify(method: "initialized", params: nil)
            try requireCurrentConnection(socket, generation: generation)
            state = .connected
            startHeartbeat(socket, generation: generation)
        } catch {
            failConnection(error, generation: generation)
            throw error
        }
    }

    func disconnect() {
        closeConnection(error: CodexRPCError(code: nil, message: "Codex engine disconnected"))
        state = .disconnected
    }

    private func closeConnection(error: Error) {
        // Invalidate callbacks before cancelling tasks that may still complete.
        connectionID = UUID()
        connectionTask?.cancel()
        connectionTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        heartbeatDeadlineTask?.cancel()
        heartbeatDeadlineTask = nil
        pendingPingID = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        session?.invalidateAndCancel()
        session = nil
        let continuations = Array(pending.values)
        pending.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }

    func request(method: String, params: JSONValue? = nil) async throws -> JSONValue {
        guard let socket else {
            throw CodexRPCError(code: nil, message: "Codex engine is not connected")
        }

        let id = nextRequestID
        nextRequestID += 1
        var object: [String: JSONValue] = [
            "id": .integer(Int64(id)),
            "method": .string(method)
        ]
        if let params {
            object["params"] = params
        }

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
                Task { [weak self, weak socket] in
                    guard let self, let socket, self.pending[id] != nil else { return }
                    do {
                        try await self.send(.object(object), through: socket)
                    } catch {
                        self.resolveRequest(id: id, with: .failure(error))
                    }
                }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                self?.resolveRequest(id: id, with: .failure(CancellationError()))
            }
        }
    }

    func notify(method: String, params: JSONValue? = nil) async throws {
        guard let socket else {
            throw CodexRPCError(code: nil, message: "Codex engine is not connected")
        }
        var object: [String: JSONValue] = ["method": .string(method)]
        if let params {
            object["params"] = params
        }
        try await send(.object(object), through: socket)
    }

    func respond(to id: JSONValue, result: JSONValue) async throws {
        guard let socket else {
            throw CodexRPCError(code: nil, message: "Codex engine is not connected")
        }
        try await send(
            .object(["id": id, "result": result]),
            through: socket
        )
    }

    func respondUnsupported(to id: JSONValue, method: String) async throws {
        guard let socket else {
            throw CodexRPCError(code: nil, message: "Codex engine is not connected")
        }
        try await send(
            .object([
                "id": id,
                "error": .object([
                    "code": .integer(-32601),
                    "message": .string("CodexPad does not support server request \(method)")
                ])
            ]),
            through: socket
        )
    }

    private func receiveMessages(from socket: URLSessionWebSocketTask, generation: UUID) async {
        while !Task.isCancelled {
            do {
                let message = try await socket.receive()
                try requireCurrentConnection(socket, generation: generation)
                let data: Data
                switch message {
                case .string(let text):
                    data = Data(text.utf8)
                case .data(let payload):
                    data = payload
                @unknown default:
                    continue
                }
                let value = try JSONDecoder().decode(JSONValue.self, from: data)
                handle(value)
            } catch {
                if !Task.isCancelled {
                    failConnection(error, generation: generation)
                }
                return
            }
        }
    }

    private func handle(_ value: JSONValue) {
        guard let object = value.objectValue else { return }
        let method = object["method"]?.stringValue
        let params = object["params"] ?? .object([:])

        if let method, let id = object["id"] {
            inboundHandler?(.request(id: id, method: method, params: params))
            return
        }
        if let method {
            inboundHandler?(.notification(method: method, params: params))
            return
        }
        guard let id = object["id"]?.intValue else { return }
        if let result = object["result"] {
            resolveRequest(id: id, with: .success(result))
            return
        }
        if let error = object["error"]?.objectValue {
            resolveRequest(
                id: id,
                with: .failure(CodexRPCError(
                    code: error["code"]?.intValue,
                    message: error["message"]?.stringValue ?? "Unknown app-server error"
                ))
            )
        }
    }

    private func send(_ value: JSONValue, through socket: URLSessionWebSocketTask) async throws {
        let generation = connectionID
        try requireCurrentConnection(socket, generation: generation)
        let data = try JSONEncoder().encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CodexRPCError(code: nil, message: "Could not encode app-server message")
        }
        do {
            try await socket.send(.string(text))
            try requireCurrentConnection(socket, generation: generation)
        } catch {
            failConnection(error, generation: generation)
            throw error
        }
    }

    private func requireCurrentConnection(_ socket: URLSessionWebSocketTask, generation: UUID) throws {
        guard connectionID == generation, self.socket === socket else {
            throw CodexRPCError(code: nil, message: "Codex engine connection was replaced")
        }
    }

    private func startHeartbeat(_ socket: URLSessionWebSocketTask, generation: UUID) {
        heartbeatTask = Task { [weak self, weak socket] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(20)) } catch { return }
                guard let self, let socket, self.connectionID == generation else { return }
                self.sendHeartbeat(socket, generation: generation)
            }
        }
    }

    private func sendHeartbeat(_ socket: URLSessionWebSocketTask, generation: UUID) {
        guard pendingPingID == nil else { return }
        let pingID = UUID()
        pendingPingID = pingID
        heartbeatDeadlineTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            guard let self, self.pendingPingID == pingID else { return }
            self.failConnection(
                CodexRPCError(code: nil, message: "Codex engine heartbeat timed out"),
                generation: generation
            )
        }
        socket.sendPing { [weak self] error in
            Task { @MainActor in
                guard let self, self.connectionID == generation, self.pendingPingID == pingID else { return }
                self.heartbeatDeadlineTask?.cancel()
                self.heartbeatDeadlineTask = nil
                self.pendingPingID = nil
                if let error { self.failConnection(error, generation: generation) }
            }
        }
    }

    private func resolveRequest(id: Int, with result: Result<JSONValue, Error>) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        continuation.resume(with: result)
    }

    private func failConnection(_ error: Error, generation: UUID) {
        guard connectionID == generation else { return }
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        closeConnection(error: error)
        state = .failed(message)
        connectionFailureHandler?(message)
    }
}

private extension Bundle {
    var releaseVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}
