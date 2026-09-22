import Foundation
import Darwin

private struct RegressionFailure: Error, CustomStringConvertible {
    let description: String
}

@main
struct ConnectionRegression {
    @MainActor
    static func main() async {
        do {
            guard CommandLine.arguments.count == 2,
                  let port = Int(CommandLine.arguments[1]) else {
                throw RegressionFailure(description: "Usage: connection-regression PORT")
            }
            try await handshakeDeadline(port: port)
            try await droppedConnectionAndConcurrentConnect(port: port)
            print("PASS: all RPC connection regressions")
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            exit(1)
        }
    }

    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw RegressionFailure(description: message) }
    }

    static func stats(port: Int, path: String) async throws -> [String: Int] {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/stats")!)
        request.timeoutInterval = 2
        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode([String: [String: Int]].self, from: data)
        guard let value = result[path] else {
            throw RegressionFailure(description: "Missing fixture stats for \(path)")
        }
        return value
    }

    static func waitForCount(port: Int, key: String, count: Int) async throws -> [String: Int] {
        let deadline = Date().addingTimeInterval(2)
        repeat {
            let value = try await stats(port: port, path: "normal")
            if value[key] == count { return value }
            try await Task.sleep(for: .milliseconds(25))
        } while Date() < deadline
        throw RegressionFailure(description: "Fixture never observed \(key)=\(count)")
    }

    @MainActor
    static func handshakeDeadline(port: Int) async throws {
        print("TEST: initialize reply withheld; expect the 8-second deadline")
        let client = CodexRPCClient(endpoint: URL(string: "ws://127.0.0.1:\(port)/silent")!)
        defer { client.disconnect() }
        var failures = 0
        client.connectionFailureHandler = { _ in failures += 1 }
        let started = Date()
        var didFail = false
        do {
            try await client.connect()
        } catch {
            didFail = true
        }
        let elapsed = Date().timeIntervalSince(started)
        try check(didFail, "Silent initialize unexpectedly succeeded")
        try check(elapsed >= 7 && elapsed < 12, "Handshake deadline took \(elapsed)s")
        guard case .failed = client.state else {
            throw RegressionFailure(description: "Handshake timeout did not leave failed state")
        }
        try check(failures == 1, "Handshake emitted \(failures) failure callbacks")
        let observed = try await stats(port: port, path: "silent")
        try check(observed["connections"] == 1 && observed["initialize"] == 1,
                  "Fixture did not complete the WebSocket upgrade and receive initialize")
        print("PASS: handshake deadline (\(String(format: "%.2f", elapsed))s)")
    }

    @MainActor
    static func droppedConnectionAndConcurrentConnect(port: Int) async throws {
        print("TEST: eight concurrent connect calls, pending failures, reconnect")
        let client = CodexRPCClient(endpoint: URL(string: "ws://127.0.0.1:\(port)/normal")!)
        defer { client.disconnect() }
        var failures = 0
        client.connectionFailureHandler = { _ in failures += 1 }
        let connections = (0..<8).map { _ in Task { try await client.connect() } }
        for connection in connections { try await connection.value }
        try check(client.state == .connected, "Concurrent connect did not establish a connection")
        let initial = try await waitForCount(port: port, key: "initialized", count: 1)
        try check(initial["connections"] == 1 && initial["initialize"] == 1,
                  "Concurrent connect created duplicate WebSockets or handshakes: \(initial)")
        let generation = client.connectionID
        let requests = (0..<3).map { _ in
            Task {
                do {
                    _ = try await client.request(method: "hold")
                    return false
                } catch {
                    return true
                }
            }
        }
        _ = try await waitForCount(port: port, key: "pending", count: 3)
        let closedAt = Date()
        try? await client.notify(method: "close")
        for request in requests {
            try check(await request.value, "A held request succeeded instead of failing on disconnect")
        }
        try check(Date().timeIntervalSince(closedAt) < 3, "Pending continuations were not released promptly")
        try check(failures == 1, "One dropped connection emitted \(failures) failure callbacks")
        try check(client.connectionID != generation, "Connection generation was not invalidated")
        guard case .failed = client.state else {
            throw RegressionFailure(description: "Dropped connection retained connected state")
        }
        var staleRequestFailed = false
        do { _ = try await client.request(method: "echo") } catch { staleRequestFailed = true }
        try check(staleRequestFailed, "Request used a closed socket")

        try await client.connect()
        let echo = try await client.request(method: "echo", params: .object(["afterReconnect": .bool(true)]))
        try check(echo["afterReconnect"]?.boolValue == true, "Reconnected socket could not exchange RPC messages")
        let reconnected = try await waitForCount(port: port, key: "initialized", count: 2)
        try check(reconnected["connections"] == 2 && reconnected["initialize"] == 2,
                  "Reconnect created unexpected connections: \(reconnected)")
        try await Task.sleep(for: .milliseconds(300))
        try check(client.state == .connected && failures == 1, "Old callbacks poisoned the replacement connection")
        print("PASS: connect deduplication, all pending failures, replacement connection")
    }
}
