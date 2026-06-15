# TASK-260615-1zlpve: implement-session-event-core

## Description
Implement testable coordinator core logic for E2E sessions: session ids, peer registry, append-only event store, event predicates, wait outcomes, timeout handling, and heartbeats.

## Scope
Implement transport-independent coordinator domain logic with deterministic dependencies for clock, ids, event store, waits, and receipts. No xcodebuild, filesystem, product-project semantics, or transport-specific networking in core.

## Acceptance Criteria
Core logic is independent from xcodebuild, HTTP, filesystem, and wall-clock side effects. Swift tests cover event append/query, peer registration, wait success, wait timeout, and missing-peer cases.
