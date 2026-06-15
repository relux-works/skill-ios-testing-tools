# TASK-260615-27ds5k: implement-uitestkit-e2e-client

## Description
Implement UITestKit E2E client APIs that UI test targets import to read coordinator environment, register/identify peer, emit events, wait for peer events, send heartbeat, and attach synchronization evidence.

## Scope
Implement UI-test-facing client API in UITestKit: environment parsing, WebSocket connection lifecycle, event publication, wait predicates, delivery receipt handling, heartbeat, reconnect metadata, and diagnostics.

## Acceptance Criteria
A sample UI test can create the client from environment, emit an event, wait for another peer event, and fail with actionable diagnostics when the coordinator is unreachable or a wait times out. Client behavior is covered with mocked transport tests where practical.
