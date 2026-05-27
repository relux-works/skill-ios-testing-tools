# Physical iOS/iOS E2E Synchronization

Use this reference for end-to-end tests where two physical iPhones must coordinate app state, nearby discovery, BLE advertisement/scanning, peer visibility, or session handoff.

## Core Rule

Wait for observable facts, not wall-clock phases.

Do not drive a paired-device scenario with sleeps such as "wait 30 seconds, then switch the other phone". Model the scenario as a small state machine and advance only after the other device reports the expected marker or UI state.

Fixed sleeps hide the real failure point and make passing runs slow. Reactive waits make passing runs advance as soon as the state appears and make broken runs fail at the missing state with the relevant log and screenshot.

## Reactive Orchestration Pattern

The harness should follow this shape:

1. Start device A in its initial long-running role, for example receiver/reclamation mode.
2. Start device B test, for example sender lookup.
3. Wait until device B reports the expected peer/state marker.
4. Recheck the state after a short stability interval inside the test when the signal can flap.
5. Trigger the next transition on device A.
6. Wait until device B reports the next marker.
7. Repeat until the scenario finishes.
8. Clean up both devices.

Bounded timeouts are still required, but they guard a wait. They must not be the mechanism that advances the scenario.

## Long-Running Roles

Do not use a short XCUITest method to keep a device in a long-running role if the app must stay alive after the method returns. XCTest teardown can close or reset the app, leaving the other device looking for a peer that is already gone.

Prefer this split:

- Launch the long-running endpoint as a normal app process through `devicectl`.
- Use app automation configuration from launch environment variables or launch arguments to enter the desired initial state.
- Use short XCUITest methods only to poke the running app into the next state, such as switching tabs or toggling a mode.
- Keep assertions and screenshots on the observing endpoint where possible.

Example receiver launch:

```bash
automation_env='{"APP_AUTOMATION_SIGNED_IN":"true","APP_AUTOMATION_RECEIVER_MODE":"true"}'

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun devicectl device process launch \
  --device <receiver-udid> \
  --terminate-existing \
  --environment-variables "$automation_env" \
  --json-output .temp/receiver-launch.json \
  --log-output .temp/receiver-launch.log \
  <bundle-id>
```

Use `--environment-variables` when possible. Dash-prefixed app launch arguments can be fragile because they are easy to confuse with tool options, and environment values are also easier to log and template.

## Marker Contract

Markers should be emitted at points where the harness can safely advance:

- lookup started
- peer detected
- peer still visible after a short stability recheck
- peer disappeared after the other device leaves advertisement/receiver mode
- peer reappeared after the other device returns
- receiver mode stopped
- receiver mode restarted

Use screenshot attachments for these markers so the `xcresult` tells the same story as the text log.

## Harness Algorithm

Use one long-running test process for the observing side and short attach/poke tests for the controlled side:

```text
build/install receiver app
launch receiver app in receiver mode

start sender XCUITest in background
wait_for_log_marker(sender.log, "peer_still_visible")

run receiver XCUITest: switch_to_send_mode
wait_for_log_marker(sender.log, "peer_disappeared")

run receiver XCUITest: switch_to_receive_mode
wait for sender XCUITest to finish and assert "peer_reappeared"

terminate receiver app
```

`wait_for_log_marker` should:

- poll the log or structured status file once per second or similarly cheaply
- return immediately when the marker appears
- fail immediately if the test process reports failure
- fail if the test process exits before the expected marker
- fail with a bounded timeout and tail the relevant log

## App Bundle Resolution

Do not assume that `xcodebuild -derivedDataPath <path> build` always leaves the app under that exact path in Tuist or generated-workspace projects.

Resolve the built app from multiple sources:

- requested derived data products path
- repo-local `DerivedData/Build/Products/<configuration>-iphoneos`
- absolute `.app` paths found in the build log

Fail with the build-log tail if no bundle is found.

## Device Readiness

Before a two-device run, verify both devices independently:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun devicectl device info lockState \
  --device <device-udid> \
  --timeout 30 \
  --json-output .temp/device-lockstate.json \
  --log-output .temp/device-lockstate.log
```

Both devices should acquire a tunnel connection and report that the device has been unlocked since boot.

Run a small smoke XCUITest on each phone before starting a long paired run when the devices were recently rebooted, re-trusted, or recovered from tunnel errors.

## Common Problems

### Receiver App Closes Too Early

Symptom: the sender reaches lookup, but the receiver app is no longer running.

Fix: do not boot the receiver through a short XCUITest. Build/install the app, launch it as a normal app process, and use short attach tests only for transitions.

### Device Is Paired But CoreDevice Tunnel Fails

Symptoms:

- `RemotePairingError Code=4`
- `tunnelState: disconnected`
- `ddiServicesAvailable: false`
- `devicectl device info lockState` fails

Fix:

- unlock the device
- re-issue Trust if prompted
- reconnect with a known-good data cable
- reboot the device if needed
- use the iPhone Developer networking Responsiveness test when the tunnel remains stuck
- rerun `devicectl device info lockState`

### UI Automation Mode Stalls

Symptom: XCUITest times out while enabling automation mode.

Fix:

- terminate stale `automationmode-writer` or `testmanagerd` processes only when it is safe for the current workstation state
- uninstall the app and UI test runner
- rerun a small smoke test on that device

### Xcode 26 Attachment Extraction Fails

Symptom: helper screenshot extraction fails on a modern `.xcresult`.

Fix: inspect attachments with `xcresulttool test-report` / attachment commands manually until the helper supports that result format. The screenshot attachments are the source of truth for final UI state.

## Artifacts To Keep

For each paired-device run, keep artifacts under a task-scoped `.temp/` directory:

- full harness log
- receiver build log
- receiver install JSON/log
- receiver launch JSON/log
- receiver poke test logs and `.xcresult` bundles
- sender log and `.xcresult` bundle
- device readiness JSON/logs

Record the successful run directory in the task board or worklog so the next agent can inspect the exact evidence.
