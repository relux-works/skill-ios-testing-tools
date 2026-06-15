import Foundation
import IOSE2ECoordinatorCore

struct UITestE2EEnvelope: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
}

enum UITestE2EOutboundMessage: Encodable, Sendable {
    case hello(UITestE2EHelloMessage)
    case publish(UITestE2EPublishMessage)
    case eventAck(UITestE2EEventAckMessage)
    case heartbeat(UITestE2EHeartbeatMessage)

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .hello(message):
            try message.encode(to: encoder)
        case let .publish(message):
            try message.encode(to: encoder)
        case let .eventAck(message):
            try message.encode(to: encoder)
        case let .heartbeat(message):
            try message.encode(to: encoder)
        }
    }
}

enum UITestE2EInboundMessage: Equatable, Sendable {
    case event(UITestE2EObservedEvent)
    case receipt(UITestE2EPublishReceiptMessage)
    case other(String)

    var event: UITestE2EObservedEvent? {
        if case let .event(event) = self {
            return event
        }

        return nil
    }

    var receipt: UITestE2EPublishReceiptMessage? {
        if case let .receipt(receipt) = self {
            return receipt
        }

        return nil
    }
}

struct UITestE2EHelloMessage: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let peerName: String
    let peerRole: String?
    let lastSeenSeq: Int

    init(
        sessionId: String,
        peerName: String,
        peerRole: String?,
        lastSeenSeq: Int
    ) {
        self.type = "hello"
        self.protocolVersion = 1
        self.sessionId = sessionId
        self.peerName = peerName
        self.peerRole = peerRole
        self.lastSeenSeq = lastSeenSeq
    }
}

struct UITestE2EWelcomeMessage: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let peerId: String
    let peerName: String
    let lastSeq: Int
    let replay: [UITestE2EEventMessage]
}

struct UITestE2EPublishMessage: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let peerName: String
    let clientMessageId: String
    let eventName: String
    let payloadFormat: String
    let payload: E2EJSONValue
    let delivery: UITestE2EDeliveryMessage

    init(
        sessionId: String,
        peerName: String,
        clientMessageId: String,
        eventName: String,
        payloadFormat: String,
        payload: E2EJSONValue,
        delivery: UITestE2EDeliveryMessage
    ) {
        self.type = "publish"
        self.protocolVersion = 1
        self.sessionId = sessionId
        self.peerName = peerName
        self.clientMessageId = clientMessageId
        self.eventName = eventName
        self.payloadFormat = payloadFormat
        self.payload = payload
        self.delivery = delivery
    }
}

struct UITestE2EDeliveryMessage: Codable, Equatable, Sendable {
    let requirement: String
    let requiredPeers: [String]?

    init(_ delivery: UITestE2EDelivery) {
        self.requirement = delivery.requirement
        self.requiredPeers = delivery.requiredPeers
    }
}

struct UITestE2EEventMessage: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let eventId: String
    let seq: Int
    let name: String
    let originPeer: String
    let payloadFormat: String
    let payload: E2EJSONValue

    var observedEvent: UITestE2EObservedEvent {
        UITestE2EObservedEvent(
            id: E2EEventID(eventId),
            seq: E2EEventSeq(seq),
            name: name,
            originPeer: E2EPeerName(originPeer),
            payloadFormat: payloadFormat,
            payload: payload
        )
    }
}

public struct UITestE2EPublishReceiptMessage: Codable, Equatable, Sendable {
    public let type: String
    public let protocolVersion: Int
    public let sessionId: String
    public let clientMessageId: String
    public let eventId: String
    public let seq: Int
    public let requirement: String
    public let state: String
    public let deliveredTo: [String]
    public let ackedBy: [String]
}

struct UITestE2EHeartbeatMessage: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let peerName: String
    let lastSeenSeq: Int

    init(sessionId: String, peerName: String, lastSeenSeq: Int) {
        self.type = "heartbeat"
        self.protocolVersion = 1
        self.sessionId = sessionId
        self.peerName = peerName
        self.lastSeenSeq = lastSeenSeq
    }
}

struct UITestE2EEventAckMessage: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let peerName: String
    let eventId: String
    let seq: Int

    init(sessionId: String, peerName: String, eventId: String, seq: Int) {
        self.type = "eventAck"
        self.protocolVersion = 1
        self.sessionId = sessionId
        self.peerName = peerName
        self.eventId = eventId
        self.seq = seq
    }
}
