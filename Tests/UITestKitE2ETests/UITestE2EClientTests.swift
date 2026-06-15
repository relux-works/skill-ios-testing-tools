import Foundation
import IOSE2ECoordinatorCore
import Testing
@testable import IOSE2EPeerClient

@Suite
struct UITestE2EClientTests {
    @Test
    func parsesRequiredEnvironment() throws {
        let environment = try UITestE2EEnvironment.parse([
            "E2E_SESSION_ID": "session-1",
            "E2E_PROFILE_NAME": "profile",
            "E2E_PEER_NAME": "alpha",
            "E2E_PEER_ROLE": "primary",
            "E2E_COORDINATOR_URL": "ws://127.0.0.1:9000/e2e/session",
            "E2E_ARTIFACTS_DIR": ".temp/run/alpha",
            "E2E_LAST_SEEN_SEQ": "7"
        ])

        #expect(environment.sessionID == E2ESessionID("session-1"))
        #expect(environment.profileName == "profile")
        #expect(environment.peerName == "alpha")
        #expect(environment.peerNameValue == "alpha")
        #expect(environment.peerRole == "primary")
        #expect(environment.coordinatorURL.absoluteString == "ws://127.0.0.1:9000/e2e/session")
        #expect(environment.artifactsDirectory == ".temp/run/alpha")
        #expect(environment.lastSeenSeq == E2EEventSeq(7))
    }

    @Test
    func parsesPeerListenerEnvironment() throws {
        let environment = try UITestE2EEnvironment.parse([
            "E2E_SESSION_ID": "session-1",
            "E2E_PEER_NAME": "alpha",
            "E2E_COORDINATOR_URL": "tcp-listener://127.0.0.1:19131/e2e/session",
            "E2E_TRANSPORT": "peer-listener",
            "E2E_PEER_LISTEN_PORT": "19131"
        ])

        #expect(environment.transportKind == .peerListener)
        #expect(environment.peerListenPort == 19131)
        #expect(environment.coordinatorURL.absoluteString == "tcp-listener://127.0.0.1:19131/e2e/session")
    }

    @Test
    func rejectsPeerListenerWithoutListenPort() {
        #expect(throws: UITestE2EClientError.missingEnvironmentValue("E2E_PEER_LISTEN_PORT")) {
            _ = try UITestE2EEnvironment.parse([
                "E2E_SESSION_ID": "session-1",
                "E2E_PEER_NAME": "alpha",
                "E2E_COORDINATOR_URL": "tcp-listener://127.0.0.1:19131/e2e/session",
                "E2E_TRANSPORT": "peer-listener"
            ])
        }
    }

    @Test
    func rejectsMissingEnvironmentValues() {
        #expect(throws: UITestE2EClientError.missingEnvironmentValue("E2E_SESSION_ID")) {
            _ = try UITestE2EEnvironment.parse([:])
        }
    }

    @Test
    func connectSendsHelloAndBuffersReplay() async throws {
        let transport = MockE2ETransport(inbound: [
            welcome(replay: [
                eventObject(name: "beta.ready", originPeer: "beta", seq: 3)
            ], lastSeq: 3)
        ])
        let client = UITestE2EClient(environment: environment(), transport: transport)

        try await client.connect()

        #expect(transport.connectedURL?.absoluteString == "ws://127.0.0.1:9000/e2e/session")
        let hello = try #require(transport.sentJSON.first)
        #expect(hello["type"] as? String == "hello")
        #expect(hello["peerName"] as? String == "alpha")
        #expect(hello["lastSeenSeq"] as? Int == 0)
        #expect(transport.sentJSON.contains { sent in
            sent["type"] as? String == "eventAck"
                && sent["eventId"] as? String == "event-3"
                && sent["seq"] as? Int == 3
        })

        let replayed = try await client.waitFor("beta.ready", originPeer: "beta", timeout: 0.1)
        #expect(replayed.seq == E2EEventSeq(3))
    }

    @Test
    func publishSendsJsonPayloadAndWaitsForRequiredReceipt() async throws {
        let transport = MockE2ETransport(inbound: [
            welcome()
        ])
        let client = UITestE2EClient(environment: environment(), transport: transport)
        try await client.connect()

        let receipt = try await client.publish(
            "alpha.ready",
            payload: .object(["ready": .bool(true)]),
            delivery: .acked(requiredPeers: ["beta"])
        )

        let publish = try #require(transport.sentJSON.last)
        #expect(publish["type"] as? String == "publish")
        #expect(publish["eventName"] as? String == "alpha.ready")
        #expect(receipt.state == "acked")
        #expect(receipt.ackedBy == ["beta"])
    }

    @Test
    func waitForConsumesLiveEvents() async throws {
        let transport = MockE2ETransport(inbound: [
            welcome(),
            event(name: "ignored", originPeer: "beta", seq: 1),
            event(name: "beta.ready", originPeer: "beta", seq: 2)
        ])
        let client = UITestE2EClient(environment: environment(), transport: transport)
        try await client.connect()

        let observed = try await client.waitFor("beta.ready", originPeer: "beta", timeout: 1)

        #expect(observed.name == "beta.ready")
        #expect(observed.seq == E2EEventSeq(2))
        #expect(transport.sentJSON.contains { sent in
            sent["type"] as? String == "eventAck"
                && sent["eventId"] as? String == "event-2"
                && sent["seq"] as? Int == 2
        })
    }

    @Test
    func waitForTimeoutReportsRecentEvents() async throws {
        let transport = MockE2ETransport(inbound: [
            welcome(),
            event(name: "beta.other", originPeer: "beta", seq: 1)
        ])
        let client = UITestE2EClient(environment: environment(), transport: transport)
        try await client.connect()

        do {
            _ = try await client.waitFor("beta.ready", originPeer: "beta", timeout: 0.01)
            Issue.record("Expected timeout")
        } catch let error as UITestE2EClientError {
            guard case let .waitTimedOut(eventName, _, peerName, lastSeenSeq, recentEvents) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(eventName == "beta.ready")
            #expect(peerName == "alpha")
            #expect(lastSeenSeq == E2EEventSeq(1))
            #expect(recentEvents == ["beta.other"])
        }
    }
}

private func environment() -> UITestE2EEnvironment {
    UITestE2EEnvironment(
        sessionID: E2ESessionID("session-1"),
        profileName: "profile",
        peerName: "alpha",
        peerRole: "primary",
        coordinatorURL: URL(string: "ws://127.0.0.1:9000/e2e/session")!,
        transportKind: .websocket,
        peerListenPort: nil,
        artifactsDirectory: nil,
        lastSeenSeq: E2EEventSeq(0)
    )
}

private func welcome(replay: [[String: Any]] = [], lastSeq: Int = 0) -> String {
    jsonString([
        "type": "welcome",
        "protocolVersion": 1,
        "sessionId": "session-1",
        "peerId": "peer-alpha",
        "peerName": "alpha",
        "lastSeq": lastSeq,
        "replay": replay
    ])
}

private func eventObject(name: String, originPeer: String, seq: Int) -> [String: Any] {
    [
        "type": "event",
        "protocolVersion": 1,
        "sessionId": "session-1",
        "eventId": "event-\(seq)",
        "seq": seq,
        "name": name,
        "originPeer": originPeer,
        "payloadFormat": "json",
        "payload": [:]
    ]
}

private func receipt(
    clientMessageId: String,
    state: String,
    ackedBy: [String] = []
) -> String {
    jsonString([
        "type": "publishReceipt",
        "protocolVersion": 1,
        "sessionId": "session-1",
        "clientMessageId": clientMessageId,
        "eventId": "event-1",
        "seq": 1,
        "requirement": state,
        "state": state,
        "deliveredTo": [],
        "ackedBy": ackedBy
    ])
}

private func event(name: String, originPeer: String, seq: Int) -> String {
    jsonString(eventObject(name: name, originPeer: originPeer, seq: seq))
}

private func jsonString(_ value: [String: Any]) -> String {
    let data = try! JSONSerialization.data(withJSONObject: value)
    return String(data: data, encoding: .utf8)!
}

private final class MockE2ETransport: UITestE2ETransport, @unchecked Sendable {
    var connectedURL: URL?
    var sentText: [String] = []
    var sentJSON: [[String: Any]] {
        sentText.compactMap { text in
            guard let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            return object
        }
    }

    private var inbound: [String]

    init(inbound: [String]) {
        self.inbound = inbound
    }

    func connect(url: URL) async throws {
        connectedURL = url
    }

    func send(_ text: String) async throws {
        sentText.append(text)

        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["type"] as? String == "publish",
              let clientMessageId = object["clientMessageId"] as? String else {
            return
        }

        let delivery = object["delivery"] as? [String: Any]
        let requirement = delivery?["requirement"] as? String ?? "accepted"
        let requiredPeers = delivery?["requiredPeers"] as? [String] ?? []
        inbound.append(receipt(
            clientMessageId: clientMessageId,
            state: requirement,
            ackedBy: requirement == "acked" ? requiredPeers : []
        ))
    }

    func receive() async throws -> String {
        if inbound.isEmpty {
            try await Task.sleep(nanoseconds: 100_000_000)
            return jsonString([
                "type": "heartbeat",
                "protocolVersion": 1
            ])
        }

        return inbound.removeFirst()
    }

    func close() {}
}
