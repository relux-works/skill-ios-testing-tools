## Status
done

## Assigned To
codex

## Created
2026-06-15T15:55:00Z

## Last Update
2026-06-29T14:58:20Z

## Blocked By
- (none)

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
(none)

## Outcome Resources
(none)
