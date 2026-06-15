# STORY-260615-2wpji6: uitestkit-e2e-client

## Description
Expose a small UITestKit client that UI test targets import to read peer environment, emit events, wait for peer events, and attach evidence around synchronization points.

## Scope
UITestKit client APIs only: environment parsing, WebSocket connection, event emit, event wait, heartbeat, delivery receipt handling, diagnostics, and screenshot evidence hooks.

## Acceptance Criteria
UI test code can import UITestKit, create an E2E client from environment, publish JSON events, wait for peer events with timeout diagnostics, and attach synchronization screenshots without project-specific toolkit code.
