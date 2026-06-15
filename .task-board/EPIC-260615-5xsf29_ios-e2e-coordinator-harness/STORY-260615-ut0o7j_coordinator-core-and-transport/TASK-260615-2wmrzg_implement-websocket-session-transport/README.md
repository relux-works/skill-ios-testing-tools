# TASK-260615-2wmrzg: implement-websocket-session-transport

## Description
Implement the local Mac WebSocket session transport for the E2E coordinator: server lifecycle, peer handshake, message decoding/encoding, per-peer outgoing queues, event fan-out, event acknowledgement handling, reconnect replay, and transport diagnostics.

## Scope
Implement reusable WebSocket transport target for the local Mac coordinator process. Keep session state in IOSE2ECoordinatorCore and keep the transport free of product-project semantics.

## Acceptance Criteria
Transport can start/stop a local WebSocket server, accept peer hello messages, send welcome with replay, decode publish/eventAck/heartbeat messages, fan out events to non-publisher peers, update delivery receipts, and expose diagnostics for malformed messages and disconnects.
