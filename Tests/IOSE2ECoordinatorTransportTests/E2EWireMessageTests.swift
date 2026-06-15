import Foundation
import IOSE2ECoordinatorCore
import Testing
@testable import IOSE2ECoordinatorTransport

@Suite
struct E2EWireMessageTests {
    @Test
    func deliveryMapsAckRequirementToCoreModel() {
        let delivery = E2EWireDelivery(
            requirement: "acked",
            requiredPeers: ["beta", "observer"],
            timeout: "10s"
        )

        #expect(delivery.coreRequirement == .acked(requiredPeers: ["beta", "observer"]))
    }

    @Test
    func unknownDeliveryRequirementFallsBackToAccepted() {
        let delivery = E2EWireDelivery(
            requirement: "custom",
            requiredPeers: ["beta"],
            timeout: nil
        )

        #expect(delivery.coreRequirement == .accepted)
    }

    @Test
    func serverBroadcastsPublishedEventsAndReceiptsAck() async throws {
        let core = E2ESessionEventCore(sessionID: E2ESessionID("session-1"))
        let server = E2EWebSocketCoordinatorServer(core: core)
        let port = try server.start()
        defer { try? server.stop() }

        let alpha = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)/e2e/session")!)
        let beta = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)/e2e/session")!)
        alpha.resume()
        beta.resume()
        defer {
            alpha.cancel(with: .normalClosure, reason: nil)
            beta.cancel(with: .normalClosure, reason: nil)
        }

        try await alpha.sendJSON([
            "type": "hello",
            "protocolVersion": 1,
            "sessionId": "session-1",
            "peerName": "alpha",
            "lastSeenSeq": 0
        ])
        try await beta.sendJSON([
            "type": "hello",
            "protocolVersion": 1,
            "sessionId": "session-1",
            "peerName": "beta",
            "lastSeenSeq": 0
        ])

        let alphaWelcome = try await alpha.receiveJSON()
        let betaWelcome = try await beta.receiveJSON()
        #expect(alphaWelcome["type"] as? String == "welcome")
        #expect(betaWelcome["type"] as? String == "welcome")

        try await alpha.sendJSON([
            "type": "publish",
            "protocolVersion": 1,
            "sessionId": "session-1",
            "peerName": "alpha",
            "clientMessageId": "msg-1",
            "eventName": "alpha.ready",
            "payloadFormat": "json",
            "payload": ["ready": true],
            "delivery": [
                "requirement": "acked",
                "requiredPeers": ["beta"],
                "timeout": "5s"
            ]
        ])

        let event = try await beta.receiveJSON()
        #expect(event["type"] as? String == "event")
        #expect(event["sessionId"] as? String == "session-1")
        #expect(event["name"] as? String == "alpha.ready")
        #expect(event["originPeer"] as? String == "alpha")

        let eventID = try #require(event["eventId"] as? String)
        let seq = try #require(event["seq"] as? Int)
        try await beta.sendJSON([
            "type": "eventAck",
            "protocolVersion": 1,
            "sessionId": "session-1",
            "peerName": "beta",
            "eventId": eventID,
            "seq": seq
        ])

        let finalReceipt = try await alpha.receiveReceipt(state: "acked")
        #expect(finalReceipt["type"] as? String == "publishReceipt")
        #expect(finalReceipt["sessionId"] as? String == "session-1")
        #expect(finalReceipt["eventId"] as? String == eventID)
        #expect(finalReceipt["state"] as? String == "acked")
        #expect(finalReceipt["ackedBy"] as? [String] == ["beta"])
    }

    @Test
    func serverBroadcastsToThreePeersAndReplaysForLatePeer() async throws {
        let core = E2ESessionEventCore(sessionID: E2ESessionID("session-2"))
        let server = E2EWebSocketCoordinatorServer(core: core)
        let port = try server.start()
        defer { try? server.stop() }

        let alpha = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)/e2e/session")!)
        let beta = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)/e2e/session")!)
        let observer = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)/e2e/session")!)
        alpha.resume()
        beta.resume()
        defer {
            alpha.cancel(with: .normalClosure, reason: nil)
            beta.cancel(with: .normalClosure, reason: nil)
            observer.cancel(with: .normalClosure, reason: nil)
        }

        try await alpha.sendHello(session: "session-2", peer: "alpha", lastSeenSeq: 0)
        try await beta.sendHello(session: "session-2", peer: "beta", lastSeenSeq: 0)
        _ = try await alpha.receiveJSON()
        _ = try await beta.receiveJSON()

        try await alpha.sendJSON([
            "type": "publish",
            "protocolVersion": 1,
            "sessionId": "session-2",
            "peerName": "alpha",
            "clientMessageId": "msg-1",
            "eventName": "alpha.ready",
            "payloadFormat": "json",
            "payload": ["ready": true],
            "delivery": [
                "requirement": "acked",
                "requiredPeers": ["beta", "observer"],
                "timeout": "5s"
            ]
        ])

        let betaEvent = try await beta.receiveJSON()
        #expect(betaEvent["type"] as? String == "event")
        #expect(betaEvent["name"] as? String == "alpha.ready")

        observer.resume()
        try await observer.sendHello(session: "session-2", peer: "observer", lastSeenSeq: 0)
        let observerWelcome = try await observer.receiveJSON()
        let replay = try #require(observerWelcome["replay"] as? [[String: Any]])
        #expect(replay.map { $0["name"] as? String } == ["alpha.ready"])

        let betaEventID = try #require(betaEvent["eventId"] as? String)
        let betaSeq = try #require(betaEvent["seq"] as? Int)
        let replayedEvent = try #require(replay.first)
        let observerEventID = try #require(replayedEvent["eventId"] as? String)
        let observerSeq = try #require(replayedEvent["seq"] as? Int)
        #expect(observerEventID == betaEventID)
        #expect(observerSeq == betaSeq)

        try await beta.sendAck(session: "session-2", peer: "beta", eventId: betaEventID, seq: betaSeq)
        try await observer.sendAck(session: "session-2", peer: "observer", eventId: observerEventID, seq: observerSeq)

        let finalReceipt = try await alpha.receiveReceipt(state: "acked")
        #expect(finalReceipt["ackedBy"] as? [String] == ["beta", "observer"])
    }
}

private extension URLSessionWebSocketTask {
    func sendHello(session: String, peer: String, lastSeenSeq: Int) async throws {
        try await sendJSON([
            "type": "hello",
            "protocolVersion": 1,
            "sessionId": session,
            "peerName": peer,
            "lastSeenSeq": lastSeenSeq
        ])
    }

    func sendAck(session: String, peer: String, eventId: String, seq: Int) async throws {
        try await sendJSON([
            "type": "eventAck",
            "protocolVersion": 1,
            "sessionId": session,
            "peerName": peer,
            "eventId": eventId,
            "seq": seq
        ])
    }

    func sendJSON(_ value: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: value)
        let text = try #require(String(data: data, encoding: .utf8))
        try await send(.string(text))
    }

    func receiveJSON() async throws -> [String: Any] {
        let message = try await receive()

        let data: Data
        switch message {
        case let .data(value):
            data = value
        case let .string(value):
            data = Data(value.utf8)
        @unknown default:
            Issue.record("Unsupported WebSocket message")
            return [:]
        }

        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    func receiveReceipt(state: String) async throws -> [String: Any] {
        for _ in 0..<8 {
            let message = try await receiveJSON()
            if message["type"] as? String == "publishReceipt",
               message["state"] as? String == state {
                return message
            }
        }

        Issue.record("Expected publishReceipt with state \(state)")
        return [:]
    }
}
