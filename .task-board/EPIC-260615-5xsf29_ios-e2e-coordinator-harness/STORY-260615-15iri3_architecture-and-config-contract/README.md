# STORY-260615-15iri3: architecture-and-config-contract

## Description
Define reusable WebSocket-first E2E coordinator architecture, config schema, peer identity model, event envelope, delivery guarantees, timestamp model, JSON payload model, and artifact contract before implementation.

## Scope
Architecture and contracts only: config schema, event protocol, delivery model, diagrams, risk notes, and transport follow-up decisions. No production implementation in this story.

## Acceptance Criteria
Architecture docs and diagrams describe WebSocket event bus semantics, append-only event log, broadcast except sender, publish receipts, accepted/enqueued/sent/acked delivery barriers, event replay, timestamps, JSON payloads, and sample-before-Tap2Cash rollout.
