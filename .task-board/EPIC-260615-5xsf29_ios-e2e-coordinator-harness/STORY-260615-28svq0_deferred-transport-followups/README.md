# STORY-260615-28svq0: deferred-transport-followups

## Description
Track non-MVP transport options that are explicitly blocked by external architecture decisions and must not affect WebSocket-first MVP execution.

## Scope
Deferred transport research only. This story is outside the WebSocket-first MVP critical path and must not block coordinator core, runner, client, sample, or consumer validation tasks.

## Acceptance Criteria
Deferred transport options remain blocked until a new explicit decision reopens them. WebSocket MVP tasks remain unblocked and continue without gRPC design or implementation.
