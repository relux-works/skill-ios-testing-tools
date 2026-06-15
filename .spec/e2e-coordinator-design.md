# E2E Coordinator Design

## Purpose

Build a reusable WebSocket-first E2E coordinator harness for multi-peer iOS UI test scenarios.

The harness lets a project run several peer UI tests, assign each peer a stable identity, exchange synchronization events through a local Mac coordinator, and collect one coherent run artifact set. The toolkit owns orchestration and protocol mechanics; consumer projects own product scenario steps and product-specific event naming.

## Design Decisions

- Transport MVP is WebSocket with JSON envelopes.
- gRPC bidirectional streaming is explicitly deferred by a blocked follow-up decision.
- Config authoring format is YAML; the resolved runtime model is JSON-compatible.
- Peer identity is explicit and injected by the runner through reserved `E2E_*` environment variables.
- Event waits are race-free: inspect replay/history first, then consume live stream.
- Event fan-out broadcasts to all connected non-publisher peers in the same session.
- Publishers receive delivery receipts for `accepted`, `enqueued`, `sent`, and `acked`.
- Event payloads are generic typed JSON values. Toolkit code must not parse product semantics.
- The standalone toolkit sample must pass before consumer-project integration.

## Module Ownership

### `IOSE2ECoordinatorCore`

Pure Swift core with deterministic tests.

Owns:

- `SessionID`, `PeerID`, `PeerName`, `EventID`, `EventSeq`
- session registry
- peer registry
- append-only event log
- replay query by `lastSeenSeq`
- wait predicate engine
- delivery receipt state machine
- timestamp envelope construction
- config validation rules that do not require filesystem, Xcode, or network side effects

Must not own:

- WebSocket server implementation details
- `xcodebuild` process execution
- filesystem artifact writes
- UI test APIs
- consumer product event taxonomy

### `IOSE2ECoordinatorTransport`

Mac-only transport adapter around the core.

Owns:

- local WebSocket server lifecycle
- peer connection registry
- inbound message decoding
- outbound per-peer queues
- event fan-out
- event acknowledgement handling
- connection close and reconnect handling

The concrete server library is an implementation decision hidden behind transport protocols. The core must be testable without starting a socket server.

### `IOSE2ERunner`

Mac-only executable.

Owns:

- CLI argument parsing
- config loading and validation
- session id generation
- coordinator start and shutdown
- `advertisedHost` and port resolution
- peer launch planning
- `build-for-testing` / `test-without-building` command construction
- `.xctestrun` environment patching when needed
- process supervision
- session result aggregation
- artifact collection

### `UITestKit` E2E Client

iOS UI-test-facing library code.

Owns:

- reserved environment parsing
- WebSocket client connection
- peer hello/reconnect handshake
- event publish API
- event wait API
- delivery receipt awaiting
- heartbeat
- diagnostics for missing coordinator, timeout, malformed events, and delivery failures
- optional screenshot/evidence helpers around sync points

The public API should be small enough for UI tests:

```swift
let e2e = try await UITestE2EClient.fromEnvironment()
try await e2e.publish("alpha.ready")
let event = try await e2e.waitFor("beta.condition_detected", timeout: .seconds(30))
try await e2e.publish(
    "alpha.checkpoint_reached",
    payload: .object(["step": .string("confirmed")]),
    delivery: .acked(requiredPeers: ["beta"])
)
```

## Config Contract

The config schema is defined in `e2e-coordinator-config-schema.md`.

Implementation rules:

- Parse YAML into strongly typed `Codable` models.
- Convert project-specific metadata and event payload-like fields into a `JSONValue` enum, not untyped dictionaries.
- Reject unknown top-level fields.
- Reject duplicate peer names before launching anything.
- Reject `appEnvironment` keys with the reserved `E2E_` prefix.
- Resolve `port: 0` before injecting `E2E_COORDINATOR_URL`.
- Resolve `advertisedHost: auto` before peer launch.
- Write `resolved-config.json` into artifacts.

## Reserved Runtime Environment

The runner injects these values into every peer:

- `E2E_SESSION_ID`
- `E2E_PROFILE_NAME`
- `E2E_PEER_NAME`
- `E2E_PEER_ROLE`
- `E2E_COORDINATOR_URL`
- `E2E_ARTIFACTS_DIR`
- `E2E_LAST_SEEN_SEQ`

The UI test client treats these values as the only required bootstrap channel.

## WebSocket Protocol

All messages are JSON objects with:

```json
{
  "type": "messageType",
  "protocolVersion": 1,
  "sessionId": "e2e-...",
  "peerName": "alpha"
}
```

### `hello`

Peer-to-coordinator first message.

```json
{
  "type": "hello",
  "protocolVersion": 1,
  "sessionId": "e2e-...",
  "peerName": "alpha",
  "peerRole": "primary",
  "lastSeenSeq": 0,
  "clientTime": {
    "wallTime": "2026-06-15T10:00:00.000Z",
    "monotonicMs": 1234
  }
}
```

### `welcome`

Coordinator-to-peer response.

```json
{
  "type": "welcome",
  "protocolVersion": 1,
  "sessionId": "e2e-...",
  "peerId": "peer-...",
  "peerName": "alpha",
  "lastSeq": 12,
  "replay": []
}
```

`replay` contains events with `seq > lastSeenSeq`.

### `publish`

Peer-to-coordinator event publication.

```json
{
  "type": "publish",
  "protocolVersion": 1,
  "sessionId": "e2e-...",
  "peerName": "alpha",
  "clientMessageId": "client-msg-...",
  "eventName": "alpha.ready",
  "payloadFormat": "json",
  "payload": {
    "step": "ready"
  },
  "delivery": {
    "requirement": "acked",
    "requiredPeers": ["beta"],
    "timeout": "10s"
  },
  "clientTime": {
    "wallTime": "2026-06-15T10:00:01.000Z",
    "monotonicMs": 2234
  }
}
```

### `event`

Coordinator-to-peer fan-out message.

```json
{
  "type": "event",
  "protocolVersion": 1,
  "sessionId": "e2e-...",
  "eventId": "event-...",
  "seq": 13,
  "name": "alpha.ready",
  "originPeer": "alpha",
  "payloadFormat": "json",
  "payload": {
    "step": "ready"
  },
  "time": {
    "peerWallTime": "2026-06-15T10:00:01.000Z",
    "peerMonotonicMs": 2234,
    "coordinatorWallTime": "2026-06-15T10:00:01.020Z",
    "coordinatorMonotonicMs": 99123
  }
}
```

### `eventAck`

Peer-to-coordinator acknowledgement after the peer receives and stores an event.

```json
{
  "type": "eventAck",
  "protocolVersion": 1,
  "sessionId": "e2e-...",
  "peerName": "beta",
  "eventId": "event-...",
  "seq": 13
}
```

### `publishReceipt`

Coordinator-to-publisher delivery progress.

```json
{
  "type": "publishReceipt",
  "protocolVersion": 1,
  "sessionId": "e2e-...",
  "clientMessageId": "client-msg-...",
  "eventId": "event-...",
  "seq": 13,
  "state": "acked",
  "deliveredTo": ["beta"],
  "ackedBy": ["beta"]
}
```

### `heartbeat`

Peer-to-coordinator liveness message.

```json
{
  "type": "heartbeat",
  "protocolVersion": 1,
  "sessionId": "e2e-...",
  "peerName": "alpha",
  "lastSeenSeq": 13
}
```

## Event Wait Semantics

`waitFor` is a client-side operation over a local event buffer and live stream.

Algorithm:

1. Check replayed events already received during `welcome`.
2. Check events buffered since connection.
3. Subscribe to live stream updates.
4. Return the first event matching the predicate.
5. On timeout, throw an error that includes peer name, session id, event name, timeout, last seen sequence, and recent event names.

The runner uses the same predicate model internally for `startWhen.type=event`, but does not need to expose a public request/response wait protocol to UI tests in the MVP.

## Delivery Semantics

Receipt states:

- `accepted`: core validated and appended the event to the session log.
- `enqueued`: event was placed into outbound queues for required connected recipients.
- `sent`: transport wrote the event to required recipient sockets.
- `acked`: required recipients returned `eventAck`.

Rules:

- `accepted` is enough for fire-and-forget synchronization points.
- `acked` is required when a publishing peer must not continue until another peer has received the event.
- `sent` is transport-level only; it does not prove consumer test code processed the event.
- If a required peer is disconnected and the requirement is `acked`, the publish call waits until reconnect within timeout or fails.

## Timestamp Model

Every event stores both peer and coordinator time:

- `peerWallTime`
- `peerMonotonicMs`
- `coordinatorWallTime`
- `coordinatorMonotonicMs`

Ordering uses coordinator-assigned `seq`, not wall-clock time.

Wall-clock fields are for diagnostics and cross-device timeline reading. Monotonic fields are for local interval analysis only and must not be compared across devices.

## Runner Lifecycle

1. Load and validate config.
2. Generate `sessionId`.
3. Resolve artifact root.
4. Start coordinator server.
5. Resolve coordinator advertised URL.
6. Build for testing if required by mode/config.
7. Prepare peer launch plans.
8. Start peers whose `startWhen` is `immediate`.
9. Wait for event predicates and start dependent peers.
10. Supervise all peer processes.
11. Stop coordinator after peers finish or fail.
12. Collect artifacts and write session summary.
13. Return non-zero exit status if any required peer fails.

## Artifact Contract

The runner writes:

- `resolved-config.json`
- `session-summary.json`
- `event-log.jsonl`
- `receipts.jsonl`
- `coordinator.log`
- `peers/<peerName>/launch.json`
- `peers/<peerName>/xcodebuild.log` for `xctest` peers
- `peers/<peerName>/result.xcresult` for `xctest` peers
- `peers/<peerName>/screenshots/` when extraction is enabled

The event log is append-only and uses one JSON object per line.

## Failure Modes

The harness must fail early when:

- config is invalid
- coordinator cannot bind host/port
- advertised host cannot be resolved
- physical device destination is missing
- peer process exits non-zero
- peer never connects
- heartbeat expires
- wait predicate times out
- delivery barrier times out
- artifact collection misses a required result

Every failure should include the session id, peer name if applicable, last known peer state, recent event names, and artifact root.

## Testing Strategy

Use Swift Testing for reusable package tests.

Core tests:

- config validation
- peer name uniqueness
- duration parsing
- reserved environment collision rejection
- event append/query
- replay by `lastSeenSeq`
- wait predicate success and timeout
- receipt transitions
- timestamp envelope creation with a fake clock

Transport tests:

- multiple peer connections
- publish fan-out to non-publisher peers
- `eventAck` to `publishReceipt` transition
- reconnect with replay
- malformed message diagnostics

Runner tests:

- dry-run launch plan
- Xcode command construction
- environment injection
- artifact path resolution
- process failure propagation

Sample smoke:

- start local coordinator
- launch three fake process peers
- prove broadcast, replay, `acked` delivery, JSON payloads, timestamps, and artifacts

Physical consumer validation starts only after the sample smoke passes.

## Rollout Sequence

1. Finish architecture/config contract.
2. Implement coordinator core and config models.
3. Implement runner dry-run and local process peer mode.
4. Implement WebSocket transport.
5. Implement UITestKit E2E client.
6. Add standalone sample fake peers and smoke command.
7. Validate sample artifacts.
8. Add consumer config-only slice.
9. Run physical-device readiness checks.
10. Validate consumer project without removing existing legacy scripts.
11. Update skill docs and README.

## Risks And Mitigations

| Risk | Mitigation |
| --- | --- |
| WebSocket server library choice leaks into core models. | Keep transport behind protocols and test core without sockets. |
| Physical iOS peers cannot reach the Mac coordinator host. | Support `advertisedHost: auto`, allow explicit host override, and validate localhost misuse for physical devices. |
| Local Network, ATS, firewall, or VPN settings block device access. | Make device readiness a separate gate before physical consumer validation and write diagnostics into artifacts. |
| Delivery guarantees are misunderstood by test authors. | Expose explicit `accepted`, `enqueued`, `sent`, and `acked` API choices and document when to use each. |
| Product semantics leak into toolkit samples or docs. | Keep local instructions and specs project-neutral; use `Consumer iOS project`, `AppUnderTest`, and `peer alpha/beta` placeholders. |
| A failed peer hides the useful synchronization context. | Always include recent events, last seen sequence, peer state, and artifact paths in failures. |

## Non-Goals

- No product-specific event names or scenario logic in toolkit code.
- No gRPC transport in MVP.
- No remote coordinator service.
- No persistent database.
- No implicit peer discovery from UI test class names.
- No replacement of consumer legacy harnesses before the new harness proves itself.
