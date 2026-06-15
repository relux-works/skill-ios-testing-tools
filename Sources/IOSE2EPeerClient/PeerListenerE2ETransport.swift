import Foundation
@preconcurrency import Network

final class PeerListenerE2ETransport: UITestE2ETransport, @unchecked Sendable {
    private let port: Int
    private let queue: DispatchQueue
    private let incoming: PeerListenerIncomingMessages
    private let waitForConnection: PeerListenerConnectionWaiter
    private var listener: NWListener?
    private var connection: NWConnection?

    init(port: Int) {
        self.port = port
        self.queue = DispatchQueue(label: "ios-testing-tools.e2e.peer-listener.\(port)")
        self.incoming = PeerListenerIncomingMessages()
        self.waitForConnection = PeerListenerConnectionWaiter()
    }

    func connect(url: URL) async throws {
        let listenPort = try resolvedPort(from: url)
        let nwPort = try nwPort(listenPort)
        let listener = try NWListener(using: .tcp, on: nwPort)
        self.listener = listener

        try await withCheckedThrowingContinuation { continuation in
            waitForConnection.set(continuation)

            listener.stateUpdateHandler = { [waitForConnection] state in
                switch state {
                case let .failed(error):
                    waitForConnection.resume(throwing: error)
                case .cancelled:
                    waitForConnection.resume(throwing: PeerListenerE2ETransportError.cancelled)
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self, waitForConnection] connection in
                guard let self else {
                    connection.cancel()
                    waitForConnection.resume(throwing: PeerListenerE2ETransportError.deallocated)
                    return
                }

                self.connection = connection
                self.startReceiveLoop(connection)
                connection.start(queue: self.queue)
                listener.cancel()
                waitForConnection.resume(returning: ())
            }

            listener.start(queue: queue)
        }
    }

    func send(_ text: String) async throws {
        guard let connection else {
            throw PeerListenerE2ETransportError.notConnected
        }

        let data = Data((text + "\n").utf8)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    func receive() async throws -> String {
        try await incoming.next()
    }

    func close() {
        listener?.cancel()
        listener = nil
        connection?.cancel()
        connection = nil
        Task {
            await incoming.close(PeerListenerE2ETransportError.cancelled)
        }
    }

    private func resolvedPort(from url: URL) throws -> Int {
        if let urlPort = url.port, urlPort > 0 {
            return urlPort
        }

        guard port > 0 else {
            throw PeerListenerE2ETransportError.invalidPort(port)
        }

        return port
    }

    private func nwPort(_ port: Int) throws -> NWEndpoint.Port {
        guard (1...65_535).contains(port),
              let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw PeerListenerE2ETransportError.invalidPort(port)
        }

        return nwPort
    }

    private func startReceiveLoop(_ connection: NWConnection) {
        let framer = PeerListenerLineFramer()
        receiveLoop(connection, framer: framer)
    }

    private func receiveLoop(_ connection: NWConnection, framer: PeerListenerLineFramer) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [incoming] data, _, isComplete, error in
            if let data, data.isEmpty == false {
                for line in framer.append(data) {
                    Task {
                        await incoming.append(line)
                    }
                }
            }

            if let error {
                Task {
                    await incoming.close(error)
                }
                return
            }

            if isComplete {
                Task {
                    await incoming.close(PeerListenerE2ETransportError.closed)
                }
                return
            }

            self.receiveLoop(connection, framer: framer)
        }
    }
}

private enum PeerListenerE2ETransportError: Error, Equatable, Sendable {
    case cancelled
    case closed
    case deallocated
    case invalidPort(Int)
    case notConnected
}

private final class PeerListenerConnectionWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, any Error>?
    private var isResolved = false

    func set(_ continuation: CheckedContinuation<Void, any Error>) {
        lock.lock()
        defer { lock.unlock() }

        if isResolved {
            continuation.resume(returning: ())
        } else {
            self.continuation = continuation
        }
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

private actor PeerListenerIncomingMessages {
    private var buffer: [String] = []
    private var continuations: [CheckedContinuation<String, any Error>] = []
    private var terminalError: (any Error)?

    func append(_ message: String) {
        if continuations.isEmpty {
            buffer.append(message)
        } else {
            let continuation = continuations.removeFirst()
            continuation.resume(returning: message)
        }
    }

    func next() async throws -> String {
        if buffer.isEmpty == false {
            return buffer.removeFirst()
        }

        if let terminalError {
            throw terminalError
        }

        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func close(_ error: any Error) {
        terminalError = error
        let pending = continuations
        continuations.removeAll()
        for continuation in pending {
            continuation.resume(throwing: error)
        }
    }
}

private final class PeerListenerLineFramer: @unchecked Sendable {
    private var buffer = Data()

    func append(_ data: Data) -> [String] {
        buffer.append(data)
        var lines: [String] = []
        let newline = Data([0x0A])

        while let range = buffer.range(of: newline) {
            var lineData = buffer[..<range.lowerBound]
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
