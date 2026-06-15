import Foundation
import IOSE2ECoordinatorCore

protocol E2EWireTextConnection: AnyObject, Sendable {
    func sendText(_ text: String)
}

final class E2EWireSession: @unchecked Sendable {
    private let core: E2ESessionEventCore
    private let recorder: E2EWebSocketSessionRecording?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var connectionsByPeer: [E2EPeerName: E2EWireTextConnection]
    private var eventOrigins: [E2EEventID: E2EPeerName]
    private let lock: NSRecursiveLock

    init(core: E2ESessionEventCore, recorder: E2EWebSocketSessionRecording?) {
        self.core = core
        self.recorder = recorder
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.connectionsByPeer = [:]
        self.eventOrigins = [:]
        self.lock = NSRecursiveLock()
    }

    @discardableResult
    func handleText(_ text: String, from connection: E2EWireTextConnection) throws -> E2EPeerName? {
        guard let data = text.data(using: .utf8) else {
            throw E2EWebSocketTransportError.invalidTextFrame
        }

        lock.lock()
        defer { lock.unlock() }

        let envelope = try decoder.decode(E2EWireEnvelope.self, from: data)
        switch envelope.type {
        case "hello":
            return try connect(decoder.decode(E2EWireHello.self, from: data), connection: connection)
        case "publish":
            try publish(decoder.decode(E2EWirePublish.self, from: data), from: connection)
            return nil
        case "eventAck":
            try acknowledge(decoder.decode(E2EWireEventAck.self, from: data))
            return nil
        case "heartbeat":
            try heartbeat(decoder.decode(E2EWireHeartbeat.self, from: data))
            return nil
        default:
            throw E2EWebSocketTransportError.unsupportedMessageType(envelope.type)
        }
    }

    func disconnect(peerName: E2EPeerName?) {
        guard let peerName else {
            return
        }

        lock.lock()
        connectionsByPeer[peerName] = nil
        lock.unlock()
    }

    private func connect(_ hello: E2EWireHello, connection: E2EWireTextConnection) throws -> E2EPeerName {
        let peerName = E2EPeerName(hello.peerName)
        if core.peer(named: peerName) == nil {
            _ = try core.registerPeer(name: peerName, role: hello.peerRole)
        }

        connectionsByPeer[peerName] = connection
        let replay = core.replay(after: E2EEventSeq(hello.lastSeenSeq))
        try write(E2EWireWelcome(
            sessionId: core.sessionID.rawValue,
            peerId: core.peer(named: peerName)?.id.rawValue ?? "",
            peerName: peerName.rawValue,
            lastSeq: replay.last?.seq.rawValue ?? hello.lastSeenSeq,
            replay: replay.map { E2EWireEvent(event: $0, sessionId: core.sessionID.rawValue) }
        ), to: connection)

        return peerName
    }

    private func publish(_ publish: E2EWirePublish, from connection: E2EWireTextConnection) throws {
        let requirement = publish.delivery?.coreRequirement ?? .accepted
        let result = try core.publish(E2EPublishRequest(
            clientMessageID: E2EClientMessageID(publish.clientMessageId),
            originPeer: E2EPeerName(publish.peerName),
            eventName: publish.eventName,
            payloadFormat: publish.payloadFormat,
            payload: publish.payload,
            peerTime: publish.clientTime,
            deliveryRequirement: requirement
        ))
        eventOrigins[result.event.id] = result.event.originPeer

        try writeReceipt(E2EWirePublishReceipt(receipt: result.receipt, sessionId: core.sessionID.rawValue), to: connection)

        let recipients = connectionsByPeer
            .filter { $0.key != result.event.originPeer }
            .map(\.key)
        guard !recipients.isEmpty else {
            return
        }

        let recipientSet = Set(recipients)
        let enqueued = try core.markEnqueued(eventID: result.event.id, peers: recipientSet)
        try writeReceipt(E2EWirePublishReceipt(receipt: enqueued, sessionId: core.sessionID.rawValue), to: connection)

        let event = E2EWireEvent(event: result.event, sessionId: core.sessionID.rawValue)
        recorder?.recordEventJSON(try encodedText(event))
        for peer in recipients {
            guard let recipientConnection = connectionsByPeer[peer] else {
                continue
            }

            try write(event, to: recipientConnection)
        }

        let sent = try core.markSent(eventID: result.event.id, peers: recipientSet)
        try writeReceipt(E2EWirePublishReceipt(receipt: sent, sessionId: core.sessionID.rawValue), to: connection)
    }

    private func acknowledge(_ acknowledgement: E2EWireEventAck) throws {
        let receipt = try core.acknowledge(
            eventID: E2EEventID(acknowledgement.eventId),
            by: E2EPeerName(acknowledgement.peerName)
        )

        guard let originPeer = eventOrigins[receipt.eventID],
              let connection = connectionsByPeer[originPeer] else {
            return
        }

        try writeReceipt(E2EWirePublishReceipt(receipt: receipt, sessionId: core.sessionID.rawValue), to: connection)
    }

    private func heartbeat(_ heartbeat: E2EWireHeartbeat) throws {
        guard connectionsByPeer[E2EPeerName(heartbeat.peerName)] != nil else {
            throw E2EWebSocketTransportError.peerNotConnected(E2EPeerName(heartbeat.peerName))
        }
    }

    private func write<T: Encodable>(_ message: T, to connection: E2EWireTextConnection) throws {
        connection.sendText(try encodedText(message))
    }

    private func writeReceipt(_ receipt: E2EWirePublishReceipt, to connection: E2EWireTextConnection) throws {
        recorder?.recordReceiptJSON(try encodedText(receipt))
        try write(receipt, to: connection)
    }

    private func encodedText<T: Encodable>(_ message: T) throws -> String {
        let data = try encoder.encode(message)
        guard let text = String(data: data, encoding: .utf8) else {
            throw E2EWebSocketTransportError.invalidTextFrame
        }
        return text
    }
}
