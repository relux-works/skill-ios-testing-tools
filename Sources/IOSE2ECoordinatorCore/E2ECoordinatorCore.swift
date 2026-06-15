import Foundation

public struct E2ESessionID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct E2EPeerID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct E2EPeerName: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

public struct E2EEventID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct E2EClientMessageID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct E2EEventSeq: RawRepresentable, Codable, Hashable, Sendable, Comparable {
    public let rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static func < (lhs: E2EEventSeq, rhs: E2EEventSeq) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum E2EJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([E2EJSONValue])
    case object([String: E2EJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([E2EJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: E2EJSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

public struct E2EInstant: Codable, Equatable, Sendable {
    public let wallTime: Date
    public let monotonicMs: Int64

    public init(wallTime: Date, monotonicMs: Int64) {
        self.wallTime = wallTime
        self.monotonicMs = monotonicMs
    }
}

public protocol E2EClock: Sendable {
    func now() -> E2EInstant
}

public struct E2ESystemClock: E2EClock {
    public init() {}

    public func now() -> E2EInstant {
        E2EInstant(
            wallTime: Date(),
            monotonicMs: Int64(ProcessInfo.processInfo.systemUptime * 1000)
        )
    }
}

public protocol E2EIDGenerating: AnyObject {
    func nextPeerID() -> E2EPeerID
    func nextEventID() -> E2EEventID
}

public final class E2EUUIDIDGenerator: E2EIDGenerating, @unchecked Sendable {
    public init() {}

    public func nextPeerID() -> E2EPeerID {
        E2EPeerID("peer-\(UUID().uuidString)")
    }

    public func nextEventID() -> E2EEventID {
        E2EEventID("event-\(UUID().uuidString)")
    }
}

public struct E2EPeer: Codable, Equatable, Sendable {
    public let id: E2EPeerID
    public let name: E2EPeerName
    public let role: String?
    public let registeredAt: E2EInstant

    public init(id: E2EPeerID, name: E2EPeerName, role: String?, registeredAt: E2EInstant) {
        self.id = id
        self.name = name
        self.role = role
        self.registeredAt = registeredAt
    }
}

public struct E2EEventTime: Codable, Equatable, Sendable {
    public let peerWallTime: Date?
    public let peerMonotonicMs: Int64?
    public let coordinatorWallTime: Date
    public let coordinatorMonotonicMs: Int64

    public init(peer: E2EInstant?, coordinator: E2EInstant) {
        self.peerWallTime = peer?.wallTime
        self.peerMonotonicMs = peer?.monotonicMs
        self.coordinatorWallTime = coordinator.wallTime
        self.coordinatorMonotonicMs = coordinator.monotonicMs
    }
}

public struct E2EEvent: Codable, Equatable, Sendable {
    public let id: E2EEventID
    public let seq: E2EEventSeq
    public let name: String
    public let originPeer: E2EPeerName
    public let payloadFormat: String
    public let payload: E2EJSONValue
    public let time: E2EEventTime

    public init(
        id: E2EEventID,
        seq: E2EEventSeq,
        name: String,
        originPeer: E2EPeerName,
        payloadFormat: String,
        payload: E2EJSONValue,
        time: E2EEventTime
    ) {
        self.id = id
        self.seq = seq
        self.name = name
        self.originPeer = originPeer
        self.payloadFormat = payloadFormat
        self.payload = payload
        self.time = time
    }
}

public enum E2EDeliveryRequirement: Equatable, Sendable {
    case accepted
    case enqueued(requiredPeers: Set<E2EPeerName>? = nil)
    case sent(requiredPeers: Set<E2EPeerName>? = nil)
    case acked(requiredPeers: Set<E2EPeerName>? = nil)
}

public enum E2EPublishReceiptState: String, Codable, Equatable, Sendable {
    case accepted
    case enqueued
    case sent
    case acked
}

public struct E2EPublishReceipt: Codable, Equatable, Sendable {
    public let clientMessageID: E2EClientMessageID
    public let eventID: E2EEventID
    public let seq: E2EEventSeq
    public let requirement: E2EPublishReceiptState
    public let state: E2EPublishReceiptState
    public let requiredPeers: Set<E2EPeerName>
    public let enqueuedFor: Set<E2EPeerName>
    public let sentTo: Set<E2EPeerName>
    public let acknowledgedBy: Set<E2EPeerName>

    public init(
        clientMessageID: E2EClientMessageID,
        eventID: E2EEventID,
        seq: E2EEventSeq,
        requirement: E2EPublishReceiptState,
        state: E2EPublishReceiptState,
        requiredPeers: Set<E2EPeerName>,
        enqueuedFor: Set<E2EPeerName>,
        sentTo: Set<E2EPeerName>,
        acknowledgedBy: Set<E2EPeerName>
    ) {
        self.clientMessageID = clientMessageID
        self.eventID = eventID
        self.seq = seq
        self.requirement = requirement
        self.state = state
        self.requiredPeers = requiredPeers
        self.enqueuedFor = enqueuedFor
        self.sentTo = sentTo
        self.acknowledgedBy = acknowledgedBy
    }
}

public struct E2EPublishRequest: Equatable, Sendable {
    public let clientMessageID: E2EClientMessageID
    public let originPeer: E2EPeerName
    public let eventName: String
    public let payloadFormat: String
    public let payload: E2EJSONValue
    public let peerTime: E2EInstant?
    public let deliveryRequirement: E2EDeliveryRequirement

    public init(
        clientMessageID: E2EClientMessageID,
        originPeer: E2EPeerName,
        eventName: String,
        payloadFormat: String = "json",
        payload: E2EJSONValue = .object([:]),
        peerTime: E2EInstant? = nil,
        deliveryRequirement: E2EDeliveryRequirement = .accepted
    ) {
        self.clientMessageID = clientMessageID
        self.originPeer = originPeer
        self.eventName = eventName
        self.payloadFormat = payloadFormat
        self.payload = payload
        self.peerTime = peerTime
        self.deliveryRequirement = deliveryRequirement
    }
}

public struct E2EPublishResult: Equatable, Sendable {
    public let event: E2EEvent
    public let receipt: E2EPublishReceipt

    public init(event: E2EEvent, receipt: E2EPublishReceipt) {
        self.event = event
        self.receipt = receipt
    }
}

public struct E2EEventPredicate: Equatable, Sendable {
    public let name: String?
    public let originPeer: E2EPeerName?

    public init(name: String? = nil, originPeer: E2EPeerName? = nil) {
        self.name = name
        self.originPeer = originPeer
    }

    public func matches(_ event: E2EEvent) -> Bool {
        if let name, event.name != name {
            return false
        }

        if let originPeer, event.originPeer != originPeer {
            return false
        }

        return true
    }
}

public struct E2EWaitRequest: Equatable, Sendable {
    public let predicate: E2EEventPredicate
    public let afterSeq: E2EEventSeq
    public let startedAt: E2EInstant
    public let timeoutMs: Int64

    public init(
        predicate: E2EEventPredicate,
        afterSeq: E2EEventSeq = E2EEventSeq(0),
        startedAt: E2EInstant,
        timeoutMs: Int64
    ) {
        self.predicate = predicate
        self.afterSeq = afterSeq
        self.startedAt = startedAt
        self.timeoutMs = timeoutMs
    }
}

public enum E2EWaitOutcome: Equatable, Sendable {
    case matched(E2EEvent)
    case waiting
    case timedOut
}

public enum E2ESessionCoreError: Error, Equatable, Sendable {
    case duplicatePeer(E2EPeerName)
    case unknownPeer(E2EPeerName)
    case unknownEvent(E2EEventID)
}

public final class E2ESessionEventCore {
    public let sessionID: E2ESessionID

    private let clock: any E2EClock
    private let idGenerator: any E2EIDGenerating
    private var nextSeq: Int
    private var peersByName: [E2EPeerName: E2EPeer]
    private var events: [E2EEvent]
    private var receiptsByEventID: [E2EEventID: E2EPublishReceipt]

    public init(
        sessionID: E2ESessionID,
        clock: any E2EClock = E2ESystemClock(),
        idGenerator: any E2EIDGenerating = E2EUUIDIDGenerator()
    ) {
        self.sessionID = sessionID
        self.clock = clock
        self.idGenerator = idGenerator
        self.nextSeq = 1
        self.peersByName = [:]
        self.events = []
        self.receiptsByEventID = [:]
    }

    public func registerPeer(name: E2EPeerName, role: String? = nil) throws -> E2EPeer {
        if peersByName[name] != nil {
            throw E2ESessionCoreError.duplicatePeer(name)
        }

        let peer = E2EPeer(
            id: idGenerator.nextPeerID(),
            name: name,
            role: role,
            registeredAt: clock.now()
        )
        peersByName[name] = peer
        return peer
    }

    public func peer(named name: E2EPeerName) -> E2EPeer? {
        peersByName[name]
    }

    public func allPeers() -> [E2EPeer] {
        peersByName.values.sorted { $0.name.rawValue < $1.name.rawValue }
    }

    public func publish(_ request: E2EPublishRequest) throws -> E2EPublishResult {
        guard peersByName[request.originPeer] != nil else {
            throw E2ESessionCoreError.unknownPeer(request.originPeer)
        }

        let event = E2EEvent(
            id: idGenerator.nextEventID(),
            seq: E2EEventSeq(nextSeq),
            name: request.eventName,
            originPeer: request.originPeer,
            payloadFormat: request.payloadFormat,
            payload: request.payload,
            time: E2EEventTime(peer: request.peerTime, coordinator: clock.now())
        )
        nextSeq += 1
        events.append(event)

        let receipt = E2EPublishReceipt(
            clientMessageID: request.clientMessageID,
            eventID: event.id,
            seq: event.seq,
            requirement: request.deliveryRequirement.receiptState,
            state: .accepted,
            requiredPeers: requiredPeers(for: request.deliveryRequirement, originPeer: request.originPeer),
            enqueuedFor: [],
            sentTo: [],
            acknowledgedBy: []
        )
        receiptsByEventID[event.id] = receipt

        return E2EPublishResult(event: event, receipt: receipt)
    }

    public func replay(after seq: E2EEventSeq) -> [E2EEvent] {
        events.filter { $0.seq > seq }
    }

    public func events(matching predicate: E2EEventPredicate, after seq: E2EEventSeq = E2EEventSeq(0)) -> [E2EEvent] {
        events.filter { $0.seq > seq && predicate.matches($0) }
    }

    public func evaluateWait(_ request: E2EWaitRequest, at now: E2EInstant) -> E2EWaitOutcome {
        if let event = events(matching: request.predicate, after: request.afterSeq).first {
            return .matched(event)
        }

        let elapsed = now.monotonicMs - request.startedAt.monotonicMs
        if elapsed >= request.timeoutMs {
            return .timedOut
        }

        return .waiting
    }

    public func markEnqueued(eventID: E2EEventID, peers: Set<E2EPeerName>) throws -> E2EPublishReceipt {
        try updateReceipt(eventID: eventID) { receipt in
            receipt.with(enqueuedFor: receipt.enqueuedFor.union(peers))
        }
    }

    public func markSent(eventID: E2EEventID, peers: Set<E2EPeerName>) throws -> E2EPublishReceipt {
        try updateReceipt(eventID: eventID) { receipt in
            receipt.with(sentTo: receipt.sentTo.union(peers))
        }
    }

    public func acknowledge(eventID: E2EEventID, by peer: E2EPeerName) throws -> E2EPublishReceipt {
        guard peersByName[peer] != nil else {
            throw E2ESessionCoreError.unknownPeer(peer)
        }

        return try updateReceipt(eventID: eventID) { receipt in
            receipt.with(acknowledgedBy: receipt.acknowledgedBy.union([peer]))
        }
    }

    public func receipt(for eventID: E2EEventID) -> E2EPublishReceipt? {
        receiptsByEventID[eventID]
    }

    private func requiredPeers(
        for requirement: E2EDeliveryRequirement,
        originPeer: E2EPeerName
    ) -> Set<E2EPeerName> {
        switch requirement {
        case .accepted:
            return []
        case let .enqueued(peers), let .sent(peers), let .acked(peers):
            if let peers {
                return peers
            }

            return Set(peersByName.keys.filter { $0 != originPeer })
        }
    }

    private func updateReceipt(
        eventID: E2EEventID,
        mutate: (E2EPublishReceipt) -> E2EPublishReceipt
    ) throws -> E2EPublishReceipt {
        guard let receipt = receiptsByEventID[eventID] else {
            throw E2ESessionCoreError.unknownEvent(eventID)
        }

        let updated = mutate(receipt).advanced()
        receiptsByEventID[eventID] = updated
        return updated
    }
}

private extension E2EDeliveryRequirement {
    var receiptState: E2EPublishReceiptState {
        switch self {
        case .accepted:
            return .accepted
        case .enqueued:
            return .enqueued
        case .sent:
            return .sent
        case .acked:
            return .acked
        }
    }
}

private extension E2EPublishReceipt {
    func with(
        enqueuedFor: Set<E2EPeerName>? = nil,
        sentTo: Set<E2EPeerName>? = nil,
        acknowledgedBy: Set<E2EPeerName>? = nil
    ) -> E2EPublishReceipt {
        E2EPublishReceipt(
            clientMessageID: clientMessageID,
            eventID: eventID,
            seq: seq,
            requirement: requirement,
            state: state,
            requiredPeers: requiredPeers,
            enqueuedFor: enqueuedFor ?? self.enqueuedFor,
            sentTo: sentTo ?? self.sentTo,
            acknowledgedBy: acknowledgedBy ?? self.acknowledgedBy
        )
    }

    func advanced() -> E2EPublishReceipt {
        let nextState: E2EPublishReceiptState

        if requirement == .accepted {
            nextState = .accepted
        } else if !requiredPeers.isEmpty, acknowledgedBy.isSuperset(of: requiredPeers) {
            nextState = .acked
        } else if !requiredPeers.isEmpty, sentTo.isSuperset(of: requiredPeers) {
            nextState = .sent
        } else if !requiredPeers.isEmpty, enqueuedFor.isSuperset(of: requiredPeers) {
            nextState = .enqueued
        } else if requiredPeers.isEmpty, !acknowledgedBy.isEmpty {
            nextState = .acked
        } else if requiredPeers.isEmpty, !sentTo.isEmpty {
            nextState = .sent
        } else if requiredPeers.isEmpty, !enqueuedFor.isEmpty {
            nextState = .enqueued
        } else {
            nextState = state
        }

        return E2EPublishReceipt(
            clientMessageID: clientMessageID,
            eventID: eventID,
            seq: seq,
            requirement: requirement,
            state: nextState,
            requiredPeers: requiredPeers,
            enqueuedFor: enqueuedFor,
            sentTo: sentTo,
            acknowledgedBy: acknowledgedBy
        )
    }
}
