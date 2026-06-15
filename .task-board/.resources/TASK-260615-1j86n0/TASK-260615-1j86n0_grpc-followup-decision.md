# gRPC Follow-up Decision

Task: `TASK-260615-1j86n0 record-grpc-transport-followup`

## Decision

Do not implement gRPC in the MVP.

The MVP transport is WebSocket with JSON event envelopes. gRPC bidirectional streaming should be revisited only after the standalone sample and Tap2Cash proof show a concrete need that WebSocket does not handle well.

## Why Deferred

- UI test peers primarily need event streaming, broadcast, replay, and delivery receipts.
- WebSocket covers the required async peer-to-peer coordination model with less setup cost.
- JSON envelopes keep payloads inspectable in artifacts and easier to evolve while the protocol is still moving.
- gRPC would add protobuf/schema tooling, generated code, and more transport surface before the harness contract is proven.

## Revisit Criteria

Reopen gRPC evaluation if one of these becomes true:

- Strong typed schemas become more valuable than JSON artifact readability.
- Large binary payloads or strict stream backpressure become required.
- Cross-language non-Swift peers become first-class consumers.
- WebSocket server/client reliability becomes the dominant source of harness flakiness.
