# TASK-260615-59f5jb: write-e2e-coordinator-design

## Description
Write the architecture design for the reusable WebSocket-first E2E coordinator, including module boundaries, transport strategy, peer identity environment, session lifecycle, event envelope, delivery receipt guarantees, timestamp model, JSON payload model, artifact contract, testing strategy, sample proof, and generic consumer rollout path.

## Scope
Write the design narrative that implementation tasks can follow without chat context: module ownership, protocol messages, time model, payload format, delivery guarantees, testing strategy, rollout sequence, and non-goals.

## Acceptance Criteria
Design covers coordinator core, UITestKit client, runner CLI, config schema, WebSocket protocol, event replay, delivery barriers, JSON payloads, time fields, artifact flow, failure modes, explicit non-goals, sample proof, and generic consumer adoption without legacy harness removal.
