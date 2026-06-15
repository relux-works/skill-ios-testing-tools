# TASK-260615-3f2aw7: add-websocket-coordinator-smoke-tests

## Description
Add local WebSocket coordinator smoke tests that do not require iOS devices: start the coordinator server, connect multiple peer clients, emit JSON events, receive broadcast events, verify delivery receipts, replay history, wait predicates, and timeout behavior.

## Scope
Add local WebSocket transport tests over the coordinator using fake peer clients. No physical devices and no product-project dependency.

## Acceptance Criteria
Swift tests start the coordinator, connect at least three peers, verify broadcast to non-publisher peers, publish receipt states, ack barrier, replay via lastSeenSeq, JSON payload decoding, timestamp fields, wait success, wait timeout, and useful diagnostics.
