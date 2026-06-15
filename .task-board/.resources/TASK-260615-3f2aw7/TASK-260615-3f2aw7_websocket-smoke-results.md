# WebSocket Smoke Results

Task: `TASK-260615-3f2aw7 add-websocket-coordinator-smoke-tests`

## Implemented Coverage

- Local in-process WebSocket coordinator startup.
- Two-peer live WebSocket flow:
  - `alpha` and `beta` connect.
  - both receive `welcome`.
  - `alpha` publishes an event requiring `beta` ack.
  - `beta` receives the event.
  - `beta` sends `eventAck`.
  - `alpha` receives final `publishReceipt(state: acked)`.
- Three-peer live/replay flow:
  - `alpha` and `beta` connect.
  - `alpha` publishes an event.
  - `beta` receives live broadcast.
  - `observer` connects late with `lastSeenSeq = 0`.
  - `observer` receives the event through `welcome.replay`.
  - `beta` and `observer` both ack.
  - `alpha` receives final `publishReceipt(state: acked)` with both peers.
- Wire delivery mapping tests.
- Core wait success and wait timeout coverage through `IOSE2ECoordinatorCoreTests`.

## Verification

Passing:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --filter 'IOSE2ECoordinatorCoreTests|E2EWireMessageTests'
```

Log:

```text
.temp/e2e-coordinator-harness/swift-test-core-transport-03.log
```

Result: 14 Swift Testing tests passed.
