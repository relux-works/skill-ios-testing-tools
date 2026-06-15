import Foundation
import IOSE2ECoordinatorCore

public struct UITestE2EEnvironment: Equatable, Sendable {
    public let sessionID: E2ESessionID
    public let profileName: String?
    public let peerName: E2EPeerName
    public let peerRole: String?
    public let coordinatorURL: URL
    public let transportKind: UITestE2ETransportKind
    public let peerListenPort: Int?
    public let artifactsDirectory: String?
    public let lastSeenSeq: E2EEventSeq

    public var peerNameValue: String {
        peerName.rawValue
    }

    public init(
        sessionID: E2ESessionID,
        profileName: String?,
        peerName: E2EPeerName,
        peerRole: String?,
        coordinatorURL: URL,
        transportKind: UITestE2ETransportKind = .websocket,
        peerListenPort: Int? = nil,
        artifactsDirectory: String?,
        lastSeenSeq: E2EEventSeq
    ) {
        self.sessionID = sessionID
        self.profileName = profileName
        self.peerName = peerName
        self.peerRole = peerRole
        self.coordinatorURL = coordinatorURL
        self.transportKind = transportKind
        self.peerListenPort = peerListenPort
        self.artifactsDirectory = artifactsDirectory
        self.lastSeenSeq = lastSeenSeq
    }

    public static func parse(_ environment: [String: String] = ProcessInfo.processInfo.environment) throws -> UITestE2EEnvironment {
        let sessionID = try required("E2E_SESSION_ID", in: environment)
        let peerName = try required("E2E_PEER_NAME", in: environment)
        let coordinatorURLRaw = try required("E2E_COORDINATOR_URL", in: environment)

        guard let coordinatorURL = URL(string: coordinatorURLRaw) else {
            throw UITestE2EClientError.invalidEnvironmentValue("E2E_COORDINATOR_URL", coordinatorURLRaw)
        }

        let transportRaw = environment["E2E_TRANSPORT"] ?? UITestE2ETransportKind.websocket.rawValue
        guard let transportKind = UITestE2ETransportKind(rawValue: transportRaw) else {
            throw UITestE2EClientError.invalidEnvironmentValue("E2E_TRANSPORT", transportRaw)
        }

        let peerListenPort: Int?
        if let listenPortRaw = environment["E2E_PEER_LISTEN_PORT"] {
            guard let parsedPort = Int(listenPortRaw),
                  (1...65_535).contains(parsedPort) else {
                throw UITestE2EClientError.invalidEnvironmentValue("E2E_PEER_LISTEN_PORT", listenPortRaw)
            }
            peerListenPort = parsedPort
        } else {
            peerListenPort = nil
        }

        if transportKind == .peerListener, peerListenPort == nil {
            throw UITestE2EClientError.missingEnvironmentValue("E2E_PEER_LISTEN_PORT")
        }

        let lastSeenSeqRaw = environment["E2E_LAST_SEEN_SEQ"] ?? "0"
        guard let lastSeenSeq = Int(lastSeenSeqRaw) else {
            throw UITestE2EClientError.invalidEnvironmentValue("E2E_LAST_SEEN_SEQ", lastSeenSeqRaw)
        }

        return UITestE2EEnvironment(
            sessionID: E2ESessionID(sessionID),
            profileName: environment["E2E_PROFILE_NAME"],
            peerName: E2EPeerName(peerName),
            peerRole: environment["E2E_PEER_ROLE"],
            coordinatorURL: coordinatorURL,
            transportKind: transportKind,
            peerListenPort: peerListenPort,
            artifactsDirectory: environment["E2E_ARTIFACTS_DIR"],
            lastSeenSeq: E2EEventSeq(lastSeenSeq)
        )
    }

    private static func required(_ key: String, in environment: [String: String]) throws -> String {
        guard let value = environment[key], !value.isEmpty else {
            throw UITestE2EClientError.missingEnvironmentValue(key)
        }

        return value
    }
}

public enum UITestE2ETransportKind: String, Equatable, Sendable {
    case websocket
    case peerListener = "peer-listener"
}

public enum UITestE2EClientError: Error, Equatable, Sendable {
    case missingEnvironmentValue(String)
    case invalidEnvironmentValue(String, String)
    case unexpectedMessage(String)
    case waitTimedOut(eventName: String, timeoutSeconds: TimeInterval, peerName: E2EPeerName, lastSeenSeq: E2EEventSeq, recentEvents: [String])
    case publishReceiptMissing(clientMessageID: E2EClientMessageID)
}

public enum UITestE2EDelivery: Equatable, Sendable {
    case accepted
    case enqueued(requiredPeers: [E2EPeerName]? = nil)
    case sent(requiredPeers: [E2EPeerName]? = nil)
    case acked(requiredPeers: [E2EPeerName]? = nil)

    var requirement: String {
        switch self {
        case .accepted:
            return "accepted"
        case .enqueued:
            return "enqueued"
        case .sent:
            return "sent"
        case .acked:
            return "acked"
        }
    }

    var requiredPeers: [String]? {
        switch self {
        case .accepted:
            return nil
        case let .enqueued(peers), let .sent(peers), let .acked(peers):
            return peers?.map(\.rawValue).sorted()
        }
    }
}

public struct UITestE2EObservedEvent: Equatable, Sendable {
    public let id: E2EEventID
    public let seq: E2EEventSeq
    public let name: String
    public let originPeer: E2EPeerName
    public let payloadFormat: String
    public let payload: E2EJSONValue

    public init(
        id: E2EEventID,
        seq: E2EEventSeq,
        name: String,
        originPeer: E2EPeerName,
        payloadFormat: String,
        payload: E2EJSONValue
    ) {
        self.id = id
        self.seq = seq
        self.name = name
        self.originPeer = originPeer
        self.payloadFormat = payloadFormat
        self.payload = payload
    }

    func matches(name: String, originPeer: E2EPeerName?) -> Bool {
        guard self.name == name else {
            return false
        }

        if let originPeer, self.originPeer != originPeer {
            return false
        }

        return true
    }
}

public protocol UITestE2ETransport: AnyObject, Sendable {
    func connect(url: URL) async throws
    func send(_ text: String) async throws
    func receive() async throws -> String
    func close()
}

public final class UITestE2EClient: @unchecked Sendable {
    public let environment: UITestE2EEnvironment

    private let transport: UITestE2ETransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var bufferedEvents: [UITestE2EObservedEvent]
    private var recentEvents: [String]
    private var lastSeenSeq: E2EEventSeq

    public convenience init(environment: UITestE2EEnvironment) {
        self.init(
            environment: environment,
            transport: Self.defaultTransport(environment: environment)
        )
    }

    public init(
        environment: UITestE2EEnvironment,
        transport: UITestE2ETransport
    ) {
        self.environment = environment
        self.transport = transport
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.bufferedEvents = []
        self.recentEvents = []
        self.lastSeenSeq = environment.lastSeenSeq
    }

    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) async throws -> UITestE2EClient {
        let client = UITestE2EClient(environment: try UITestE2EEnvironment.parse(environment))
        try await client.connect()
        return client
    }

    private static func defaultTransport(environment: UITestE2EEnvironment) -> UITestE2ETransport {
        switch environment.transportKind {
        case .websocket:
            return URLSessionE2ETransport()
        case .peerListener:
            return PeerListenerE2ETransport(port: environment.peerListenPort ?? 0)
        }
    }

    public func connect() async throws {
        try await transport.connect(url: environment.coordinatorURL)
        try await send(.hello(UITestE2EHelloMessage(
            sessionId: environment.sessionID.rawValue,
            peerName: environment.peerName.rawValue,
            peerRole: environment.peerRole,
            lastSeenSeq: environment.lastSeenSeq.rawValue
        )))

        let welcome = try await receiveDecoded(UITestE2EWelcomeMessage.self)
        guard welcome.type == "welcome" else {
            throw UITestE2EClientError.unexpectedMessage(welcome.type)
        }

        for replay in welcome.replay {
            try await acknowledge(eventID: replay.eventId, seq: replay.seq)
            bufferedEvents.append(replay.observedEvent)
        }
        lastSeenSeq = E2EEventSeq(welcome.lastSeq)
    }

    public func publish(
        _ eventName: String,
        payload: E2EJSONValue = .object([:]),
        delivery: UITestE2EDelivery = .accepted
    ) async throws -> UITestE2EPublishReceiptMessage {
        let clientMessageID = E2EClientMessageID("client-\(UUID().uuidString)")
        try await send(.publish(UITestE2EPublishMessage(
            sessionId: environment.sessionID.rawValue,
            peerName: environment.peerName.rawValue,
            clientMessageId: clientMessageID.rawValue,
            eventName: eventName,
            payloadFormat: "json",
            payload: payload,
            delivery: UITestE2EDeliveryMessage(delivery)
        )))

        return try await receiveReceipt(
            clientMessageID: clientMessageID,
            requiredState: delivery.requirement
        )
    }

    public func waitFor(
        _ eventName: String,
        originPeer: E2EPeerName? = nil,
        timeout: TimeInterval
    ) async throws -> UITestE2EObservedEvent {
        if let index = bufferedEvents.firstIndex(where: { $0.matches(name: eventName, originPeer: originPeer) }) {
            return bufferedEvents.remove(at: index)
        }

        return try await withTimeout(seconds: timeout) {
            while true {
                let message = try await self.receiveAny()
                if let event = message.event {
                    self.buffer(event)
                    if event.matches(name: eventName, originPeer: originPeer) {
                        return event
                    }
                }
            }
        } timeoutError: {
            UITestE2EClientError.waitTimedOut(
                eventName: eventName,
                timeoutSeconds: timeout,
                peerName: self.environment.peerName,
                lastSeenSeq: self.lastSeenSeq,
                recentEvents: self.recentEvents
            )
        }
    }

    public func heartbeat() async throws {
        try await send(.heartbeat(UITestE2EHeartbeatMessage(
            sessionId: environment.sessionID.rawValue,
            peerName: environment.peerName.rawValue,
            lastSeenSeq: lastSeenSeq.rawValue
        )))
    }

    public func close() {
        transport.close()
    }

    private func receiveReceipt(
        clientMessageID: E2EClientMessageID,
        requiredState: String
    ) async throws -> UITestE2EPublishReceiptMessage {
        for _ in 0..<32 {
            let message = try await receiveAny()
            if let event = message.event {
                buffer(event)
                continue
            }

            guard let receipt = message.receipt else {
                continue
            }

            if receipt.clientMessageId == clientMessageID.rawValue,
               receipt.state == requiredState || requiredState == "accepted" {
                return receipt
            }
        }

        throw UITestE2EClientError.publishReceiptMissing(clientMessageID: clientMessageID)
    }

    private func buffer(_ event: UITestE2EObservedEvent) {
        bufferedEvents.append(event)
        recentEvents.append(event.name)
        recentEvents = Array(recentEvents.suffix(10))
        lastSeenSeq = max(lastSeenSeq, event.seq)
    }

    private func send(_ message: UITestE2EOutboundMessage) async throws {
        let data = try encoder.encode(message)
        let text = String(decoding: data, as: UTF8.self)
        try await transport.send(text)
    }

    private func acknowledge(eventID: String, seq: Int) async throws {
        try await send(.eventAck(UITestE2EEventAckMessage(
            sessionId: environment.sessionID.rawValue,
            peerName: environment.peerName.rawValue,
            eventId: eventID,
            seq: seq
        )))
    }

    private func receiveDecoded<T: Decodable>(_ type: T.Type) async throws -> T {
        let text = try await transport.receive()
        let data = Data(text.utf8)
        return try decoder.decode(T.self, from: data)
    }

    private func receiveAny() async throws -> UITestE2EInboundMessage {
        let text = try await transport.receive()
        let data = Data(text.utf8)
        let envelope = try decoder.decode(UITestE2EEnvelope.self, from: data)

        switch envelope.type {
        case "event":
            let event = try decoder.decode(UITestE2EEventMessage.self, from: data)
            try await acknowledge(eventID: event.eventId, seq: event.seq)
            return .event(event.observedEvent)
        case "publishReceipt":
            return .receipt(try decoder.decode(UITestE2EPublishReceiptMessage.self, from: data))
        default:
            return .other(envelope.type)
        }
    }
}

private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @Sendable @escaping () async throws -> T,
    timeoutError: @Sendable @escaping () -> Error
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            let nanoseconds = UInt64(max(seconds, 0) * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
            throw timeoutError()
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
