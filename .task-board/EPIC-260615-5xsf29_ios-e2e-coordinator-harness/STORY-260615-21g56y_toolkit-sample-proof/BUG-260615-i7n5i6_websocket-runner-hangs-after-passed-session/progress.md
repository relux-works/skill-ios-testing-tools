## Status
done

## Assigned To
codex

## Created
2026-06-15T15:06:28Z

## Last Update
2026-06-15T15:13:14Z

## Blocked By
- (none)

## Blocks
- (none)

## Checklist
- [x] WebSocket runner exits after all peers complete and writes passed summary
- [x] Local sample smoke returns without manual interruption
- [x] Swift package tests cover runner completion lifecycle

## Notes
Fixed by making E2EWireSession lock reentrant for NIO same-thread channelInactive callbacks and closing tracked WebSocket child channels without blocking stop() before EventLoopGroup shutdown. Verified with swift test plus websocket and peer-listener sample smoke.

## Precondition Resources
(none)

## Outcome Resources
(none)
