# Solution Architect Validation

Task: `TASK-260615-sls4ey create-e2e-coordinator-architecture-diagrams`

## Verdict

The WebSocket-first E2E coordinator architecture is valid for the MVP.

The design keeps the reusable harness in `UITestToolkit` and leaves project-specific scenario semantics in consumer UI tests and config. Tap2Cash is modeled as the first consumer, not as a toolkit dependency.

## Accepted Architecture

- A macOS runner CLI owns config loading, coordinator lifecycle, peer launch planning, test environment injection, process supervision, and artifact collection.
- A local coordinator process exposes one WebSocket session bus per E2E session.
- UI test peers import `UITestKit`, read session and peer identity from the test environment, then publish and wait for events through the coordinator.
- Coordinator core is transport-independent and owns session store, peer registry, append-only event log, wait predicate evaluation, delivery receipts, and timestamp envelopes.
- WebSocket transport owns live connection management and per-peer outgoing queues.
- Event waits are race-free: history/replay is checked first, then the peer waits on live stream.
- Broadcast fan-out sends peer events to every connected peer in the session except the sender.
- The sender receives a publish receipt. Receipt levels are `accepted`, `enqueued`, `sent`, and `acked`.
- Event payloads are project-neutral JSON envelopes with `payloadFormat: json`, a typed JSON payload, `seq`, peer time, and coordinator time fields.

## Why WebSocket For MVP

WebSocket matches UI test needs better than request/response RPC because peers must await events from other peers without polling. It also keeps the first implementation small enough to test locally with fake peers before involving Xcode or physical devices.

gRPC bidirectional streaming remains a follow-up option, not an MVP dependency.

## Validation Against Tap2Cash

- Tap2Cash-specific transfer events stay in Tap2Cash UI test scenario code or config.
- Toolkit code must not contain Tap2Cash domain names, transfer semantics, phone number flow logic, backend assumptions, or old marker-bridge script behavior.
- Tap2Cash adoption should add only config, peer mapping, test selectors, environment values, and minimal invocation glue while preserving existing physical E2E scripts.

## Risks And Gates

- Server library choice still needs implementation validation. Keep it behind transport abstractions.
- Physical iPhone connectivity to a Mac-hosted local coordinator must be validated before Tap2Cash physical proof.
- iOS local network, ATS, host address, and firewall behavior may require explicit config guidance.
- Delivery guarantees must be documented precisely so tests choose `accepted`, `sent`, or `acked` intentionally.
- The standalone toolkit sample is mandatory before Tap2Cash integration.

## Task Plan Check

The board plan is coherent:

1. Architecture and config contract.
2. Coordinator core and runner CLI.
3. UITestKit E2E client.
4. Standalone toolkit sample proof.
5. Tap2Cash device readiness.
6. Tap2Cash config-only consumer slice.
7. Documentation and rollout.
