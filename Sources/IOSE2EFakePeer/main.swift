import Darwin
import Foundation
import IOSE2ECoordinatorCore

struct FakePeerOptions: Equatable {
    var scenario: String?
    var delayMs: UInt64 = 0
    var timeout: TimeInterval = 5
    var help = false

    static func parse(_ arguments: [String]) throws -> FakePeerOptions {
        var options = FakePeerOptions()
        var index = 1

        func requireValue(for flag: String) throws -> String {
            guard index + 1 < arguments.count else {
                throw FakePeerError.invalidArguments("Missing value for \(flag).")
            }
            index += 1
            return arguments[index]
        }

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--scenario":
                options.scenario = try requireValue(for: argument)
            case "--delay-ms":
                let value = try requireValue(for: argument)
                guard let delay = UInt64(value) else {
                    throw FakePeerError.invalidArguments("Invalid --delay-ms value \(value).")
                }
                options.delayMs = delay
            case "--timeout":
                let value = try requireValue(for: argument)
                guard let timeout = TimeInterval(value) else {
                    throw FakePeerError.invalidArguments("Invalid --timeout value \(value).")
                }
                options.timeout = timeout
            case "--help", "-h":
                options.help = true
            default:
                throw FakePeerError.invalidArguments("Unknown argument: \(argument).")
            }

            index += 1
        }

        return options
    }
}

enum FakePeerError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case unknownScenario(String)
    case invalidPayload(String)
    case publishDidNotAck(String)

    var description: String {
        switch self {
        case let .invalidArguments(message):
            return message
        case let .unknownScenario(scenario):
            return "Unknown scenario \(scenario)."
        case let .invalidPayload(message):
            return message
        case let .publishDidNotAck(state):
            return "Publish did not reach acked state. Last state: \(state)."
        }
    }
}

@main
struct FakePeerMain {
    static func main() async {
        do {
            let options = try FakePeerOptions.parse(CommandLine.arguments)
            if options.help {
                printUsage()
                return
            }

            if options.delayMs > 0 {
                try await Task.sleep(nanoseconds: options.delayMs * 1_000_000)
            }

            let client = FakePeerClient(environment: try FakePeerEnvironment.parse())
            try await client.connect()
            defer { client.close() }

            let scenario = options.scenario ?? client.environment.peerName
            switch scenario {
            case "alpha":
                try await runAlpha(client: client)
            case "beta":
                try await runBeta(client: client, timeout: options.timeout)
            case "observer":
                try await runObserver(client: client, timeout: options.timeout)
            default:
                throw FakePeerError.unknownScenario(scenario)
            }
        } catch let error as FakePeerError {
            print("Error: \(error.description)")
            exit(1)
        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }

    private static func runAlpha(client: FakePeerClient) async throws {
        let receipt = try await client.publish(
            "alpha.ready",
            payload: .object([
                "sample": .string("websocket-coordinator"),
                "origin": .string("alpha"),
                "ready": .bool(true)
            ]),
            delivery: .acked(requiredPeers: ["beta", "observer"])
        )

        guard receipt.state == "acked" else {
            throw FakePeerError.publishDidNotAck(receipt.state)
        }
        print("alpha.ready ackedBy=\(receipt.ackedBy.sorted().joined(separator: ","))")

        _ = try await client.publish(
            "alpha.completed",
            payload: .object([
                "ackedBy": .array(receipt.ackedBy.sorted().map(E2EJSONValue.string))
            ]),
            delivery: .accepted
        )
    }

    private static func runBeta(client: FakePeerClient, timeout: TimeInterval) async throws {
        let event = try await client.waitFor("alpha.ready", originPeer: "alpha", timeout: timeout)
        try assertReadyEvent(event)
        print("beta observed alpha.ready seq=\(event.seq)")
        _ = try await client.publish(
            "beta.observed",
            payload: .object([
                "observedSeq": .number(Double(event.seq))
            ]),
            delivery: .accepted
        )
    }

    private static func runObserver(client: FakePeerClient, timeout: TimeInterval) async throws {
        let event = try await client.waitFor("alpha.ready", originPeer: "alpha", timeout: timeout)
        try assertReadyEvent(event)
        print("observer observed alpha.ready seq=\(event.seq) replayCount=\(client.replayCount)")
        _ = try await client.publish(
            "observer.replayed",
            payload: .object([
                "observedSeq": .number(Double(event.seq))
            ]),
            delivery: .accepted
        )
    }

    private static func assertReadyEvent(_ event: FakePeerEvent) throws {
        guard case let .object(values) = event.payload,
              values["sample"] == .string("websocket-coordinator"),
              values["origin"] == .string("alpha"),
              values["ready"] == .bool(true) else {
            throw FakePeerError.invalidPayload("alpha.ready payload did not match expected JSON object.")
        }

        guard event.time.coordinatorMonotonicMs > 0 else {
            throw FakePeerError.invalidPayload("alpha.ready event is missing coordinator monotonic timestamp.")
        }
    }

    private static func printUsage() {
        print("""
        e2e-fake-peer - Sample process peer for the generalized iOS E2E coordinator.

        Usage:
          e2e-fake-peer [--scenario alpha|beta|observer] [--delay-ms value] [--timeout seconds]

        The peer reads E2E_* environment values produced by ios-e2e-runner.
        """)
    }
}

struct FakePeerEnvironment: Equatable, Sendable {
    var sessionID: String
    var peerName: String
    var peerRole: String?
    var coordinatorURL: URL
    var lastSeenSeq: Int

    static func parse(_ environment: [String: String] = ProcessInfo.processInfo.environment) throws -> FakePeerEnvironment {
        let sessionID = try required("E2E_SESSION_ID", in: environment)
        let peerName = try required("E2E_PEER_NAME", in: environment)
        let coordinatorURLRaw = try required("E2E_COORDINATOR_URL", in: environment)
        guard let coordinatorURL = URL(string: coordinatorURLRaw) else {
            throw FakePeerError.invalidArguments("Invalid E2E_COORDINATOR_URL \(coordinatorURLRaw).")
        }

        let lastSeenSeqRaw = environment["E2E_LAST_SEEN_SEQ"] ?? "0"
        guard let lastSeenSeq = Int(lastSeenSeqRaw) else {
            throw FakePeerError.invalidArguments("Invalid E2E_LAST_SEEN_SEQ \(lastSeenSeqRaw).")
        }

        return FakePeerEnvironment(
            sessionID: sessionID,
            peerName: peerName,
            peerRole: environment["E2E_PEER_ROLE"],
            coordinatorURL: coordinatorURL,
            lastSeenSeq: lastSeenSeq
        )
    }

    private static func required(_ key: String, in environment: [String: String]) throws -> String {
        guard let value = environment[key], value.isEmpty == false else {
            throw FakePeerError.invalidArguments("Missing \(key).")
        }
        return value
    }
}

final class FakePeerClient: @unchecked Sendable {
    let environment: FakePeerEnvironment
    private(set) var replayCount = 0

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var task: URLSessionWebSocketTask?
    private var bufferedEvents: [FakePeerEvent] = []

    init(environment: FakePeerEnvironment) {
        self.environment = environment
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func connect() async throws {
        let task = URLSession.shared.webSocketTask(with: environment.coordinatorURL)
        self.task = task
        task.resume()

        try await send(FakePeerHello(
            sessionId: environment.sessionID,
            peerName: environment.peerName,
            peerRole: environment.peerRole,
            lastSeenSeq: environment.lastSeenSeq
        ))

        let welcome = try await receiveDecoded(FakePeerWelcome.self)
        for replay in welcome.replay {
            try await acknowledge(eventID: replay.eventId, seq: replay.seq)
            bufferedEvents.append(replay.observedEvent)
            replayCount += 1
        }
    }

    func publish(
        _ name: String,
        payload: E2EJSONValue,
        delivery: FakePeerDelivery = .accepted,
        timeout: TimeInterval = 10
    ) async throws -> FakePeerReceipt {
        let clientMessageID = "client-\(UUID().uuidString)"
        try await send(FakePeerPublish(
            sessionId: environment.sessionID,
            peerName: environment.peerName,
            clientMessageId: clientMessageID,
            eventName: name,
            payloadFormat: "json",
            payload: payload,
            delivery: delivery.message
        ))

        return try await withTimeout(seconds: timeout) {
            for _ in 0..<64 {
                let message = try await self.receiveAny()
                switch message {
                case let .event(event):
                    self.bufferedEvents.append(event)
                case let .receipt(receipt):
                    if receipt.clientMessageId == clientMessageID,
                       receipt.state == delivery.requirement || delivery.requirement == "accepted" {
                        return receipt
                    }
                case .other:
                    continue
                }
            }

            throw FakePeerError.publishDidNotAck("missingReceipt")
        }
    }

    func waitFor(_ name: String, originPeer: String, timeout: TimeInterval) async throws -> FakePeerEvent {
        if let index = bufferedEvents.firstIndex(where: { $0.name == name && $0.originPeer == originPeer }) {
            return bufferedEvents.remove(at: index)
        }

        return try await withTimeout(seconds: timeout) {
            while true {
                let message = try await self.receiveAny()
                switch message {
                case let .event(event):
                    if event.name == name && event.originPeer == originPeer {
                        return event
                    }
                    self.bufferedEvents.append(event)
                case .receipt, .other:
                    continue
                }
            }
        }
    }

    func close() {
        task?.cancel(with: .normalClosure, reason: nil)
    }

    private func acknowledge(eventID: String, seq: Int) async throws {
        try await send(FakePeerEventAck(
            sessionId: environment.sessionID,
            peerName: environment.peerName,
            eventId: eventID,
            seq: seq
        ))
    }

    private func send<T: Encodable>(_ value: T) async throws {
        guard let task else {
            throw FakePeerError.invalidArguments("Peer is not connected.")
        }

        let data = try encoder.encode(value)
        try await task.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func receiveDecoded<T: Decodable>(_ type: T.Type) async throws -> T {
        let text = try await receiveText()
        return try decoder.decode(T.self, from: Data(text.utf8))
    }

    private func receiveAny() async throws -> FakePeerInbound {
        let text = try await receiveText()
        let data = Data(text.utf8)
        let envelope = try decoder.decode(FakePeerEnvelope.self, from: data)

        switch envelope.type {
        case "event":
            let event = try decoder.decode(FakePeerEventMessage.self, from: data)
            try await acknowledge(eventID: event.eventId, seq: event.seq)
            return .event(event.observedEvent)
        case "publishReceipt":
            return .receipt(try decoder.decode(FakePeerReceipt.self, from: data))
        default:
            return .other(envelope.type)
        }
    }

    private func receiveText() async throws -> String {
        guard let task else {
            throw FakePeerError.invalidArguments("Peer is not connected.")
        }

        let message = try await task.receive()
        switch message {
        case let .string(text):
            return text
        case let .data(data):
            return String(decoding: data, as: UTF8.self)
        @unknown default:
            throw FakePeerError.invalidArguments("Unsupported WebSocket message.")
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
                throw FakePeerError.invalidArguments("Timed out after \(seconds)s.")
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

enum FakePeerDelivery: Equatable, Sendable {
    case accepted
    case acked(requiredPeers: [String])

    var requirement: String {
        switch self {
        case .accepted:
            return "accepted"
        case .acked:
            return "acked"
        }
    }

    var message: FakePeerDeliveryMessage {
        switch self {
        case .accepted:
            return FakePeerDeliveryMessage(requirement: "accepted", requiredPeers: nil)
        case let .acked(peers):
            return FakePeerDeliveryMessage(requirement: "acked", requiredPeers: peers)
        }
    }
}

enum FakePeerInbound: Equatable, Sendable {
    case event(FakePeerEvent)
    case receipt(FakePeerReceipt)
    case other(String)
}

struct FakePeerEvent: Equatable, Sendable {
    var eventId: String
    var seq: Int
    var name: String
    var originPeer: String
    var payload: E2EJSONValue
    var time: E2EEventTime
}

struct FakePeerEnvelope: Codable, Equatable, Sendable {
    var type: String
    var protocolVersion: Int
}

struct FakePeerHello: Codable, Equatable, Sendable {
    var type = "hello"
    var protocolVersion = 1
    var sessionId: String
    var peerName: String
    var peerRole: String?
    var lastSeenSeq: Int
}

struct FakePeerWelcome: Codable, Equatable, Sendable {
    var type: String
    var protocolVersion: Int
    var sessionId: String
    var peerId: String
    var peerName: String
    var lastSeq: Int
    var replay: [FakePeerEventMessage]
}

struct FakePeerPublish: Codable, Equatable, Sendable {
    var type = "publish"
    var protocolVersion = 1
    var sessionId: String
    var peerName: String
    var clientMessageId: String
    var eventName: String
    var payloadFormat: String
    var payload: E2EJSONValue
    var delivery: FakePeerDeliveryMessage
}

struct FakePeerDeliveryMessage: Codable, Equatable, Sendable {
    var requirement: String
    var requiredPeers: [String]?
}

struct FakePeerEventMessage: Codable, Equatable, Sendable {
    var type: String
    var protocolVersion: Int
    var sessionId: String
    var eventId: String
    var seq: Int
    var name: String
    var originPeer: String
    var payloadFormat: String
    var payload: E2EJSONValue
    var time: E2EEventTime

    var observedEvent: FakePeerEvent {
        FakePeerEvent(
            eventId: eventId,
            seq: seq,
            name: name,
            originPeer: originPeer,
            payload: payload,
            time: time
        )
    }
}

struct FakePeerEventAck: Codable, Equatable, Sendable {
    var type = "eventAck"
    var protocolVersion = 1
    var sessionId: String
    var peerName: String
    var eventId: String
    var seq: Int
}

struct FakePeerReceipt: Codable, Equatable, Sendable {
    var type: String
    var protocolVersion: Int
    var sessionId: String
    var clientMessageId: String
    var eventId: String
    var seq: Int
    var requirement: String
    var state: String
    var deliveredTo: [String]
    var ackedBy: [String]
}
