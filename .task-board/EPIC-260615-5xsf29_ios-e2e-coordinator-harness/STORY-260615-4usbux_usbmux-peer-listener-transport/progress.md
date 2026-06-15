## Status
completed

## Assigned To
codex

## Created
2026-06-15T15:55:00Z

## Last Update
2026-06-15T14:02:00Z

## Blocked By
- None.

## Blocks
- STORY-260615-3lefgg

## Checklist
- [x] Add peer-listener transport to UITestKit.
- [x] Add Mac-side peer connection registry and TCP client transport.
- [x] Add `iproxy` launch planning for physical peers.
- [x] Add local sample smoke for the listener/client protocol.
- [x] Wire Tap2Cash smoke config/script without breaking existing WebSocket path.
- [x] Run package tests and physical smoke where possible.

## Notes
- Research artifact in Tap2Cash task scope: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/ios-usb-e2e-transport-research.md`.
- Direction is host-client to device-listener because `iproxy` provides host-local-port to device-port forwarding, not an iOS-to-host reverse tunnel.
- The Mac-side TCP coordinator must treat the peer `hello` as connection readiness. TCP readiness to `iproxy` alone is insufficient because `iproxy` can accept locally while the device listener is not running yet.
- Product UI tests should import `IOSE2EPeerClient` for generalized E2E coordination and keep `UITestKit` for common UI helpers. Use `UITestE2EEnvironment.peerNameValue` instead of importing `IOSE2ECoordinatorCore` just to branch on peer names.
- Runner failure diagnostics were tightened so peer processes are terminated on cancellation and peer logs are still written when coordinator connection setup fails.
- After iPhone1 reboot/unlock/replug, `devicectl lockState` acquired a CoreDevice tunnel and `unlockedSinceBoot: true`.
- Removed the hidden `UITestKit -> IOSE2EPeerClient` re-export/dependency because Tuist/SPM could link `IOSE2ECoordinatorCore` into both `IOSE2EPeerClient.framework` and the UI test bundle. Consumers now depend on `IOSE2EPeerClient` explicitly when they need E2E coordination.
- `iproxy` may log transient `Connection refused` rows before the device-side listener starts. Treat it as noise when the final peer statuses are `0` and the session summary is `passed`.

## Precondition Resources
- `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/ios-usb-e2e-transport-research.md`

## Outcome Resources
- Toolkit package tests: `.temp/TASK-260615-usb-transport/swift-test-08.log`.
- Toolkit peer-listener sample smoke: `.temp/TASK-260615-usb-transport/peer-listener-sample-smoke-04.log`, artifacts in `.temp/e2e-peer-listener-sample/listener-smoke-04/`.
- Tap2Cash peer-listener dry run: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/tap2cash-dry-peer-listener-01.log`.
- Tap2Cash peer-listener dry run after runner diagnostics changes: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/tap2cash-dry-peer-listener-02.log`.
- Tap2Cash WebSocket dry run after dual-mode script changes: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/tap2cash-dry-websocket-02.log`.
- Tap2Cash physical peer-listener pass: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/physical-peer-listener-smoke-02/`.
- Tap2Cash physical rerun blocker evidence: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/physical-peer-listener-smoke-04/`, `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/isaac-clarke-details-04.json`, `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/isaac-clarke-lockstate-after-host-reset-04.log`.
- Post-responsiveness blocker evidence: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/isaac-clarke-details-after-user-run-host-reset.json`, `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/isaac-clarke-lockstate-after-user-run-host-reset.log`, `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/ioreg-usb-devices-after-user-run.log`, `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/isaac-clarke-2-lockstate-after-user-run.json`.
- iPhone1 light smoke failure evidence: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/iphone1-light-smoke-01/xcodebuild.log`, `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/iphone1-light-smoke-01/light-smoke.xcresult`.
- iPhone1 post-reboot CoreDevice recovery: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/iphone1-light-smoke-lockstate-02.log`, `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/iphone1-light-smoke-xcdevice-02.log`.
- iPhone1 light smoke after recovery, before linkage fix: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/iphone1-light-smoke-02/`.
- Toolkit linkage fix test: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/toolkit-linkage-fix-01/swift-test.log`.
- Tap2Cash Tuist regeneration after linkage fix: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/tap2cash-tuist-linkage-fix-01/tuist-generate.log`.
- iPhone1 light smoke after linkage fix: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/iphone1-light-smoke-03/`; no `implemented in both` runtime warnings.
- Tap2Cash physical peer-listener pass after reboot/linkage fix: `/Users/alexis/src/x-platform-airdrop/.temp/TASK-260615-sz4ypr/physical-peer-listener-smoke-05/`; `session-summary.json` status is `passed`, both peers status `0`, event log contains `peer-a.ready`, `peer-b.ready`, `peer-a.completed`.
