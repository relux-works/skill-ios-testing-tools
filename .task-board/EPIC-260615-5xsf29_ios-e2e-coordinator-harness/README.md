# EPIC-260615-5xsf29: ios-e2e-coordinator-harness

## Description
Reusable Swift-based iOS E2E coordinator harness for multi-peer XCUITest sessions. The toolkit owns session lifecycle, peer launch, WebSocket event transport, environment injection, delivery receipts, JSON event payloads, timestamp envelopes, and artifact collection; projects provide config and UI test scenario code only.

## Scope
Deliver a reusable WebSocket-first iOS E2E harness in UITestToolkit: coordinator core, macOS runner CLI, UITestKit peer client, sample proof, documentation, and Tap2Cash config-only validation. Exclude replacing the existing Tap2Cash harness, adding project-domain semantics to toolkit code, and implementing gRPC before the MVP proof.

## Acceptance Criteria
Toolkit provides a WebSocket-first session event bus, UITestKit E2E client, Swift runner CLI, tested coordinator core, standalone sample proof, documentation, and Tap2Cash consumer validation without breaking existing Tap2Cash harnesses.
