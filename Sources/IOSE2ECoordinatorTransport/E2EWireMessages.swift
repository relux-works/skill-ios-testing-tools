import Foundation
import IOSE2ECoordinatorCore

struct E2EWireEnvelope: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
}

struct E2EWireHello: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let peerName: String
    let peerRole: String?
    let lastSeenSeq: Int
    let clientTime: E2EInstant?
}

struct E2EWireWelcome: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let peerId: String
    let peerName: String
    let lastSeq: Int
    let replay: [E2EWireEvent]

    init(
        sessionId: String,
        peerId: String,
        peerName: String,
        lastSeq: Int,
        replay: [E2EWireEvent]
    ) {
        self.type = "welcome"
        self.protocolVersion = 1
        self.sessionId = sessionId
        self.peerId = peerId
        self.peerName = peerName
        self.lastSeq = lastSeq
        self.replay = replay
    }
}

struct E2EWirePublish: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let peerName: String
    let clientMessageId: String
    let eventName: String
    let payloadFormat: String
    let payload: E2EJSONValue
    let delivery: E2EWireDelivery?
    let clientTime: E2EInstant?
}

struct E2EWireDelivery: Codable, Equatable, Sendable {
    let requirement: String
    let requiredPeers: [String]?
    let timeout: String?

    var coreRequirement: E2EDeliveryRequirement {
        let peers = requiredPeers.map { Set($0.map { E2EPeerName($0) }) }

        switch requirement {
        case "enqueued":
            return .enqueued(requiredPeers: peers)
        case "sent":
            return .sent(requiredPeers: peers)
        case "acked":
            return .acked(requiredPeers: peers)
        default:
            return .accepted
        }
    }
}

struct E2EWireEvent: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let eventId: String
    let seq: Int
    let name: String
    let originPeer: String
    let payloadFormat: String
    let payload: E2EJSONValue
    let time: E2EEventTime

    init(event: E2EEvent, sessionId: String) {
        self.type = "event"
        self.protocolVersion = 1
        self.sessionId = sessionId
        self.eventId = event.id.rawValue
        self.seq = event.seq.rawValue
        self.name = event.name
        self.originPeer = event.originPeer.rawValue
        self.payloadFormat = event.payloadFormat
        self.payload = event.payload
        self.time = event.time
    }
}

struct E2EWireEventAck: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let peerName: String
    let eventId: String
    let seq: Int
}

struct E2EWirePublishReceipt: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let clientMessageId: String
    let eventId: String
    let seq: Int
    let requirement: String
    let state: String
    let deliveredTo: [String]
    let ackedBy: [String]

    init(receipt: E2EPublishReceipt, sessionId: String) {
        self.type = "publishReceipt"
        self.protocolVersion = 1
        self.sessionId = sessionId
        self.clientMessageId = receipt.clientMessageID.rawValue
        self.eventId = receipt.eventID.rawValue
        self.seq = receipt.seq.rawValue
        self.requirement = receipt.requirement.rawValue
        self.state = receipt.state.rawValue
        self.deliveredTo = receipt.sentTo.map(\.rawValue).sorted()
        self.ackedBy = receipt.acknowledgedBy.map(\.rawValue).sorted()
    }
}

struct E2EWireHeartbeat: Codable, Equatable, Sendable {
    let type: String
    let protocolVersion: Int
    let sessionId: String
    let peerName: String
    let lastSeenSeq: Int
}
