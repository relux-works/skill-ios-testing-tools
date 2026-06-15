import Foundation
import Testing
@testable import IOSE2ECoordinatorCore

@Suite
struct E2ESessionEventCoreTests {
    @Test
    func registersPeersWithStableNames() throws {
        let core = makeCore()

        let alpha = try core.registerPeer(name: "alpha", role: "primary")
        let beta = try core.registerPeer(name: "beta", role: nil)

        #expect(alpha.id == E2EPeerID("peer-1"))
        #expect(alpha.name == "alpha")
        #expect(alpha.role == "primary")
        #expect(beta.id == E2EPeerID("peer-2"))
        #expect(core.allPeers().map(\.name.rawValue) == ["alpha", "beta"])
    }

    @Test
    func rejectsDuplicatePeerNames() throws {
        let core = makeCore()
        _ = try core.registerPeer(name: "alpha")

        #expect(throws: E2ESessionCoreError.duplicatePeer("alpha")) {
            _ = try core.registerPeer(name: "alpha")
        }
    }

    @Test
    func publishesEventsWithSequenceAndTimestampEnvelope() throws {
        let clock = FixedClock()
        let core = makeCore(clock: clock)
        _ = try core.registerPeer(name: "alpha")

        let peerTime = E2EInstant(wallTime: Date(timeIntervalSince1970: 50), monotonicMs: 500)
        clock.current = E2EInstant(wallTime: Date(timeIntervalSince1970: 100), monotonicMs: 1000)

        let result = try core.publish(E2EPublishRequest(
            clientMessageID: E2EClientMessageID("msg-1"),
            originPeer: "alpha",
            eventName: "alpha.ready",
            payload: .object(["ready": .bool(true)]),
            peerTime: peerTime
        ))

        #expect(result.event.id == E2EEventID("event-1"))
        #expect(result.event.seq == E2EEventSeq(1))
        #expect(result.event.payload == .object(["ready": .bool(true)]))
        #expect(result.event.time.peerWallTime == peerTime.wallTime)
        #expect(result.event.time.peerMonotonicMs == peerTime.monotonicMs)
        #expect(result.event.time.coordinatorWallTime == clock.current.wallTime)
        #expect(result.event.time.coordinatorMonotonicMs == clock.current.monotonicMs)
        #expect(result.receipt.state == .accepted)
    }

    @Test
    func rejectsPublishFromUnknownPeer() throws {
        let core = makeCore()

        #expect(throws: E2ESessionCoreError.unknownPeer("alpha")) {
            _ = try core.publish(E2EPublishRequest(
                clientMessageID: E2EClientMessageID("msg-1"),
                originPeer: "alpha",
                eventName: "alpha.ready"
            ))
        }
    }

    @Test
    func replaysEventsAfterLastSeenSequence() throws {
        let core = makeCore()
        _ = try core.registerPeer(name: "alpha")

        _ = try core.publish(messageID: "msg-1", peer: "alpha", event: "alpha.one")
        _ = try core.publish(messageID: "msg-2", peer: "alpha", event: "alpha.two")
        _ = try core.publish(messageID: "msg-3", peer: "alpha", event: "alpha.three")

        #expect(core.replay(after: E2EEventSeq(1)).map(\.name) == ["alpha.two", "alpha.three"])
        #expect(core.replay(after: E2EEventSeq(3)).isEmpty)
    }

    @Test
    func evaluatesWaitSuccessFromHistory() throws {
        let clock = FixedClock()
        let core = makeCore(clock: clock)
        _ = try core.registerPeer(name: "alpha")
        _ = try core.publish(messageID: "msg-1", peer: "alpha", event: "alpha.ready")

        let request = E2EWaitRequest(
            predicate: E2EEventPredicate(name: "alpha.ready", originPeer: "alpha"),
            startedAt: clock.current,
            timeoutMs: 1000
        )

        guard case let .matched(event) = core.evaluateWait(request, at: clock.current) else {
            Issue.record("Expected wait to match history")
            return
        }

        #expect(event.name == "alpha.ready")
    }

    @Test
    func evaluatesWaitTimeoutDeterministically() throws {
        let clock = FixedClock()
        let core = makeCore(clock: clock)

        let request = E2EWaitRequest(
            predicate: E2EEventPredicate(name: "alpha.ready"),
            startedAt: clock.current,
            timeoutMs: 1000
        )

        let waitingAt = E2EInstant(wallTime: Date(timeIntervalSince1970: 100), monotonicMs: 999)
        let timedOutAt = E2EInstant(wallTime: Date(timeIntervalSince1970: 101), monotonicMs: 1000)

        #expect(core.evaluateWait(request, at: waitingAt) == .waiting)
        #expect(core.evaluateWait(request, at: timedOutAt) == .timedOut)
    }

    @Test
    func advancesReceiptsThroughAckedDelivery() throws {
        let core = makeCore()
        _ = try core.registerPeer(name: "alpha")
        _ = try core.registerPeer(name: "beta")

        let result = try core.publish(E2EPublishRequest(
            clientMessageID: E2EClientMessageID("msg-1"),
            originPeer: "alpha",
            eventName: "alpha.checkpoint",
            deliveryRequirement: .acked(requiredPeers: ["beta"])
        ))

        #expect(result.receipt.requiredPeers == ["beta"])
        #expect(result.receipt.state == .accepted)

        let enqueued = try core.markEnqueued(eventID: result.event.id, peers: ["beta"])
        #expect(enqueued.state == .enqueued)

        let sent = try core.markSent(eventID: result.event.id, peers: ["beta"])
        #expect(sent.state == .sent)

        let acknowledged = try core.acknowledge(eventID: result.event.id, by: "beta")
        #expect(acknowledged.state == .acked)
        #expect(acknowledged.acknowledgedBy == ["beta"])
    }

    @Test
    func defaultRequiredPeersExcludePublisher() throws {
        let core = makeCore()
        _ = try core.registerPeer(name: "alpha")
        _ = try core.registerPeer(name: "beta")
        _ = try core.registerPeer(name: "observer")

        let result = try core.publish(E2EPublishRequest(
            clientMessageID: E2EClientMessageID("msg-1"),
            originPeer: "alpha",
            eventName: "alpha.ready",
            deliveryRequirement: .acked()
        ))

        #expect(result.receipt.requiredPeers == ["beta", "observer"])
    }

    @Test
    func jsonValueRoundTripsTypedObjects() throws {
        let value = E2EJSONValue.object([
            "name": .string("alpha"),
            "ready": .bool(true),
            "count": .number(2),
            "items": .array([.string("one"), .null])
        ])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(E2EJSONValue.self, from: data)

        #expect(decoded == value)
    }
}

private func makeCore(clock: FixedClock = FixedClock()) -> E2ESessionEventCore {
    E2ESessionEventCore(
        sessionID: E2ESessionID("session-1"),
        clock: clock,
        idGenerator: FixedIDGenerator()
    )
}

private extension E2ESessionEventCore {
    func publish(
        messageID: String,
        peer: E2EPeerName,
        event: String
    ) throws -> E2EPublishResult {
        try publish(E2EPublishRequest(
            clientMessageID: E2EClientMessageID(messageID),
            originPeer: peer,
            eventName: event
        ))
    }
}

private final class FixedClock: E2EClock, @unchecked Sendable {
    var current: E2EInstant

    init(
        current: E2EInstant = E2EInstant(
            wallTime: Date(timeIntervalSince1970: 0),
            monotonicMs: 0
        )
    ) {
        self.current = current
    }

    func now() -> E2EInstant {
        current
    }
}

private final class FixedIDGenerator: E2EIDGenerating, @unchecked Sendable {
    private var peerIndex = 0
    private var eventIndex = 0

    func nextPeerID() -> E2EPeerID {
        peerIndex += 1
        return E2EPeerID("peer-\(peerIndex)")
    }

    func nextEventID() -> E2EEventID {
        eventIndex += 1
        return E2EEventID("event-\(eventIndex)")
    }
}
