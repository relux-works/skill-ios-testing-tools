# TASK-260615-2s68ew: add-sample-fake-peer-runner

## Description
Add sample fake peer executables or test fixtures that connect to the coordinator through the same wire protocol as UI tests, emit JSON events, await peer events, request delivery barriers, and exit deterministically.

## Scope
Implement alpha, beta, and observer fake peer flows that exercise the same protocol contract as UI test peers without XCUITest or devices.

## Acceptance Criteria
Fake peers prove the client/coordinator protocol without physical devices. They cover emit, waitFor, acked delivery, replay after late connection, JSON payload assertions, and timestamp fields.
