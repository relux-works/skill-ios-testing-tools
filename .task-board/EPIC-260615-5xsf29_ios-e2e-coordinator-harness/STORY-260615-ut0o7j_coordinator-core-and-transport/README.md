# STORY-260615-ut0o7j: coordinator-core-and-transport

## Description
Implement the test-session event coordinator core and WebSocket transport: session store, peer registry, event log, replay, delivery receipts, ack tracking, wait predicates, timestamps, JSON payloads, and Swift tests.

## Scope
Reusable coordinator core and WebSocket transport: session registry, peer registry, append-only event log, replay, wait predicates, per-peer queues, delivery receipts, ack tracking, JSON payloads, and timestamp envelopes.

## Acceptance Criteria
Coordinator core supports N peers per session, global sequence ordering, per-peer outgoing queues, reconnect/replay via lastSeenSeq, delivery guarantees through receipts, and deterministic Swift tests without physical devices.
