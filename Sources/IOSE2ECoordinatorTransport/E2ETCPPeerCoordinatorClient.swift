import Foundation
import IOSE2ECoordinatorCore
@preconcurrency import Network

public struct E2ETCPPeerEndpoint: Equatable, Sendable {
    public var peerName: E2EPeerName
    public var host: String
    public var port: Int

    public init(peerName: E2EPeerName, host: String, port: Int) {
        self.peerName = peerName
        self.host = host
        self.port = port
    }
}

public enum E2ETCPPeerCoordinatorError: Error, Equatable, Sendable {
    case invalidPort(Int)
    case connectionTimedOut(peerName: E2EPeerName, host: String, port: Int)
    case unexpectedPeer(expected: E2EPeerName, actual: E2EPeerName)
}

public final class E2ETCPPeerCoordinatorClient: @unchecked Sendable {
    private let session: E2EWireSession
    private let queue: DispatchQueue
    private let state: E2ETCPPeerCoordinatorState

    public init(
        core: E2ESessionEventCore,
        recorder: E2EWebSocketSessionRecording? = nil
    ) {
        self.session = E2EWireSession(core: core, recorder: recorder)
        self.queue = DispatchQueue(label: "ios-testing-tools.e2e.tcp-peer-coordinator")
        self.state = E2ETCPPeerCoordinatorState()
    }

    public func connectAll(
        _ endpoints: [E2ETCPPeerEndpoint],
        timeoutSeconds: TimeInterval = 60,
        retryIntervalSeconds: TimeInterval = 0.25
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for endpoint in endpoints {
                group.addTask {
                    try await self.connect(
                        endpoint,
                        timeoutSeconds: timeoutSeconds,
                        retryIntervalSeconds: retryIntervalSeconds
                    )
                }
            }

            for try await _ in group {}
        }
    }

    public func stop() {
        Task {
            let connections = await state.removeAll()
            for connection in connections {
                connection.cancel()
            }
        }
    }

    private func connect(
        _ endpoint: E2ETCPPeerEndpoint,
        timeoutSeconds: TimeInterval,
        retryIntervalSeconds: TimeInterval
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var lastError: (any Error)?

        while Date() < deadline {
            do {
                let connection = try await connectAndHandshake(endpoint, timeoutSeconds: min(2, max(0.1, deadline.timeIntervalSinceNow)))
                await state.append(connection)
                return
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: UInt64(max(retryIntervalSeconds, 0.05) * 1_000_000_000))
            }
        }

        _ = lastError
        throw E2ETCPPeerCoordinatorError.connectionTimedOut(
            peerName: endpoint.peerName,
            host: endpoint.host,
            port: endpoint.port
        )
    }

    private func connectAndHandshake(
        _ endpoint: E2ETCPPeerEndpoint,
        timeoutSeconds: TimeInterval
    ) async throws -> NWConnection {
        let connection = try await connectOnce(endpoint, timeoutSeconds: timeoutSeconds)
        let sink = E2ENWTextConnectionSink(connection: connection)
        let handshake = E2ENWHandshakeWaiter(expectedPeerName: endpoint.peerName)
        startReceiveLoop(connection, sink: sink, framer: E2ENWLineFramer(), handshake: handshake)

        do {
            try await withTimeout(seconds: timeoutSeconds) {
                try await handshake.wait()
            } timeoutError: {
                connection.cancel()
                return E2ETCPPeerCoordinatorError.connectionTimedOut(
                    peerName: endpoint.peerName,
                    host: endpoint.host,
                    port: endpoint.port
                )
            }
        } catch {
            connection.cancel()
            throw error
        }

        return connection
    }

    private func connectOnce(
        _ endpoint: E2ETCPPeerEndpoint,
        timeoutSeconds: TimeInterval
    ) async throws -> NWConnection {
        guard (1...65_535).contains(endpoint.port),
              let port = NWEndpoint.Port(rawValue: UInt16(endpoint.port)) else {
            throw E2ETCPPeerCoordinatorError.invalidPort(endpoint.port)
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(endpoint.host),
            port: port,
            using: .tcp
        )

        try await withTimeout(seconds: timeoutSeconds) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let waiter = E2ENWConnectionWaiter(continuation: continuation)
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        waiter.resume(returning: ())
                    case let .failed(error):
                        waiter.resume(throwing: error)
                    case .cancelled:
                        waiter.resume(throwing: E2ETCPPeerCoordinatorError.connectionTimedOut(
                            peerName: endpoint.peerName,
                            host: endpoint.host,
                            port: endpoint.port
                        ))
                    default:
                        break
                    }
                }
                connection.start(queue: self.queue)
            }
        } timeoutError: {
            connection.cancel()
            return E2ETCPPeerCoordinatorError.connectionTimedOut(
                peerName: endpoint.peerName,
                host: endpoint.host,
                port: endpoint.port
            )
        }

        return connection
    }

    private func startReceiveLoop(
        _ connection: NWConnection,
        sink: E2ENWTextConnectionSink,
        framer: E2ENWLineFramer,
        handshake: E2ENWHandshakeWaiter
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [session] data, _, isComplete, error in
            if let data, data.isEmpty == false {
                for line in framer.append(data) {
                    do {
                        if let peerName = try session.handleText(line, from: sink) {
                            sink.peerName = peerName
                            handshake.succeed(peerName)
                        }
                    } catch {
                        handshake.fail(error)
                        connection.cancel()
                        return
                    }
                }
            }

            if let error {
                handshake.fail(error)
                session.disconnect(peerName: sink.peerName)
                return
            }

            if isComplete {
                handshake.fail(E2ETCPPeerCoordinatorError.connectionTimedOut(
                    peerName: handshake.expectedPeerName,
                    host: "",
                    port: 0
                ))
                session.disconnect(peerName: sink.peerName)
                return
            }

            self.startReceiveLoop(connection, sink: sink, framer: framer, handshake: handshake)
        }
    }
}

private actor E2ETCPPeerCoordinatorState {
    private var connections: [NWConnection] = []

    func append(_ connection: NWConnection) {
        connections.append(connection)
    }

    func removeAll() -> [NWConnection] {
        let current = connections
        connections.removeAll()
        return current
    }
}

private final class E2ENWTextConnectionSink: E2EWireTextConnection, @unchecked Sendable {
    let connection: NWConnection
    var peerName: E2EPeerName?

    init(connection: NWConnection) {
        self.connection = connection
    }

    func sendText(_ text: String) {
        connection.send(content: Data((text + "\n").utf8), completion: .contentProcessed { _ in })
    }
}

private final class E2ENWHandshakeWaiter: @unchecked Sendable {
    let expectedPeerName: E2EPeerName

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, any Error>?
    private var resolvedResult: Result<Void, any Error>?

    init(expectedPeerName: E2EPeerName) {
        self.expectedPeerName = expectedPeerName
    }

    func wait() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            lock.lock()
            defer { lock.unlock() }

            if let resolvedResult {
                continuation.resume(with: resolvedResult)
            } else {
                self.continuation = continuation
            }
        }
    }

    func succeed(_ peerName: E2EPeerName) {
        if peerName == expectedPeerName {
            resolve(.success(()))
        } else {
            resolve(.failure(E2ETCPPeerCoordinatorError.unexpectedPeer(
                expected: expectedPeerName,
                actual: peerName
            )))
        }
    }

    func fail(_ error: any Error) {
        resolve(.failure(error))
    }

    private func resolve(_ result: Result<Void, any Error>) {
        lock.lock()
        guard resolvedResult == nil else {
            lock.unlock()
            return
        }
        resolvedResult = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        if let continuation {
            continuation.resume(with: result)
        }
    }
}

private final class E2ENWLineFramer: @unchecked Sendable {
    private var buffer = Data()

    func append(_ data: Data) -> [String] {
        buffer.append(data)
        var lines: [String] = []
        let newline = Data([0x0A])

        while let range = buffer.range(of: newline) {
            var lineData = Data(buffer[..<range.lowerBound])
            if lineData.last == 0x0D {
                lineData.removeLast()
            }
            if let line = String(data: lineData, encoding: .utf8), line.isEmpty == false {
                lines.append(line)
            }
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
        }

        return lines
    }
}

private final class E2ENWConnectionWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, any Error>?
    private var isResolved = false

    init(continuation: CheckedContinuation<Void, any Error>) {
        self.continuation = continuation
    }

    func resume(returning value: Void) {
        resolve { $0.resume(returning: value) }
    }

    func resume(throwing error: any Error) {
        resolve { $0.resume(throwing: error) }
    }

    private func resolve(_ block: (CheckedContinuation<Void, any Error>) -> Void) {
        lock.lock()
        guard isResolved == false else {
            lock.unlock()
            return
        }
        isResolved = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        if let continuation {
            block(continuation)
        }
    }
}

private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @Sendable @escaping () async throws -> T,
    timeoutError: @Sendable @escaping () -> any Error
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
            throw timeoutError()
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
