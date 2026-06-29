# iOS E2E Coordinator Harness

## Goal

Build a reusable iOS end-to-end testing coordinator in `UITestToolkit` so projects can run multi-peer XCUITest scenarios without rewriting project-local shell harnesses.

## Scope

- Add a Swift executable facade that starts and supervises an E2E test session.
- Add a reusable WebSocket event coordinator transport that UI test peers can use from `UITestKit`.
- Assign each started peer a unique peer identity through the test run environment.
- Let project repositories provide configuration only: host/port, peer map, destinations, test selectors, and project-specific environment values.
- Use the project-neutral config schema in `e2e-coordinator-config-schema.md` for runner inputs and resolved run summaries.
- Model event messages as generic JSON envelopes with typed JSON payloads, `payloadFormat`, timestamp fields, sequence numbers, and delivery receipt semantics.
- Support event waits through history-first replay followed by live WebSocket stream consumption.
- Keep project scenarios inside project UI tests; the toolkit must not know project-specific domain concepts or business-flow semantics.
- Preserve existing project harnesses while the new runner is developed and validated.

## Initial Consumer

Use a consumer iOS app as the first integration playground, but do not break or replace its existing physical-device e2e scripts during the first implementation branch.

## Constraints

- Implement scripting logic in Swift, not Bash, except for thin compatibility wrappers if needed.
- Cover coordinator core logic with Swift tests.
- Keep physical-device side effects behind interfaces so tests can mock `xcodebuild`, `xcrun`, filesystem, and clock behavior.
- Store run artifacts under a task-scoped `.temp/` directory in the consumer project.
- Support physical iOS devices first; simulator support should not be blocked by the design.
- Support more than two peers by modeling peers and events generically.
- Defer gRPC bidirectional streaming until WebSocket sample and consumer proof results show a concrete need.

## Acceptance Criteria

- A toolkit CLI can create an E2E session from configuration and launch configured peers with unique environment values.
- A `UITestKit` client can connect over WebSocket, emit JSON events, wait for session events from a UI test runner, and request delivery barriers when a peer must not continue before recipients receive or ack the event.
- Coordinator state, peer registration, event matching, replay, delivery receipts, timeout behavior, timestamp envelopes, JSON payload handling, and config parsing are covered by Swift tests.
- A standalone toolkit sample proves the protocol with fake peers before consumer integration starts.
- A consumer project can add a config-only integration slice that runs alongside the old harness without modifying or deleting the old scripts.
- Device readiness smoke results are recorded before physical consumer validation begins.
