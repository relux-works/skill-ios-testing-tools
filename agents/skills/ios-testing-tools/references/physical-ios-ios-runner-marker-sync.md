# Physical iOS/iOS Runner Marker Synchronization

Use this reference when two physical iPhones run paired XCUITest flows in parallel and the tests must coordinate through observable events, marker files, and screenshots.

Read this together with `physical-ios-ios-e2e-sync.md`. That file explains the reactive orchestration rule; this file explains the concrete runner-app marker bridge pattern.

## Contents

- Runner app model
- Marker bridge contract
- XCTest helpers
- Host harness shape
- Screenshot and snapshot evidence
- Artifacts to keep
- Common mistakes

## Runner App Model

An Xcode `.uiTests` target installs an extra app: the XCUITest runner. The product app is still a separate app launched or attached through `XCUIApplication`.

The runner app matters because:

- UI test code executes in the runner process, not inside the product app.
- `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)` in UI test code resolves to the runner app sandbox.
- Marker files used by test code must be copied into the runner app container, not the product app container.
- The runner bundle id is usually `<UITestBundleID>.xctrunner`, for example `com.example.app.uitests.xctrunner`.

Use this model when the event bus is only for test coordination. Put events in the product app only when the product runtime explicitly owns those events.

## Marker Bridge Contract

Use two marker channels:

- stdout markers for the host harness to observe progress from `xcodebuild` logs
- runner Documents marker files for peer tests to observe progress from inside XCTest

The typical path inside each runner app is:

```text
Documents/e2e-markers/<marker-name>
```

When a peer emits a marker:

1. The XCTest writes a local marker file in its own runner container.
2. The XCTest prints a stable stdout line, for example `APP_E2E_MARKER peer_beta_peer_detected`.
3. The host harness sees the stdout line in that device's `xcodebuild` log.
4. The host copies the marker file into the other device's runner container.
5. The other XCTest unblocks when `waitForPeerE2EMarker` sees the copied marker file.

Use either raw marker lines or a prefixed format such as `APP_E2E_MARKER <marker>`. The host harness must grep the exact format emitted by the tests.

Copy to a physical device runner container with `devicectl`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun devicectl device copy to \
  --device "$TARGET_DEVICE_UDID" \
  --source "$LOCAL_MARKER_FILE" \
  --destination "Documents/e2e-markers/$MARKER_NAME" \
  --domain-type appDataContainer \
  --domain-identifier "$XCTRUNNER_BUNDLE_ID" \
  --timeout 15
```

Keep marker names stable and domain-specific:

```text
peer_alpha_ready
peer_beta_lookup_started
peer_beta_peer_detected
peer_alpha_action_requested
peer_alpha_ready_acknowledged
peer_beta_confirmed
peer_alpha_result_visible
```

## XCTest Helpers

Use helpers like these in the UI test target. Keep the marker directory under the runner app document directory.

```swift
private func e2eMarkerDirectory() throws -> URL {
    let documentDirectory = try FileManager.default.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let markerDirectory = documentDirectory.appendingPathComponent(
        "e2e-markers",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: markerDirectory,
        withIntermediateDirectories: true
    )
    return markerDirectory
}

func writeE2EMarker(_ marker: String) throws {
    let markerURL = try e2eMarkerDirectory().appendingPathComponent(marker)
    try Data().write(to: markerURL, options: .atomic)
    print("APP_E2E_MARKER \(marker)")
}

func waitForPeerE2EMarker(
    _ marker: String,
    timeout: TimeInterval = 60,
    pollInterval: TimeInterval = 0.25
) throws {
    let deadline = Date().addingTimeInterval(timeout)
    let markerURL = try e2eMarkerDirectory().appendingPathComponent(marker)

    while Date() < deadline {
        if FileManager.default.fileExists(atPath: markerURL.path) {
            return
        }
        RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
    }

    XCTFail("Timed out waiting for peer E2E marker: \(marker)")
}
```

Screenshot around each marker:

```swift
screenshot(step: 4, "peer_beta_peer_detected_before_marker", app: app)
try writeE2EMarker("peer_beta_peer_detected")
screenshot(step: 5, "peer_beta_peer_detected_after_marker", app: app)
```

When state can flap, capture before and after the stability wait:

```swift
screenshot(step: 5, "peer_visible_initial", app: app)
XCTAssertTrue(peerCell.waitForExistence(timeout: 3))
RunLoop.current.run(until: Date().addingTimeInterval(1.0))
XCTAssertTrue(peerCell.exists)
screenshot(step: 6, "peer_visible_stable", app: app)
try writeE2EMarker("peer_beta_peer_visible_stable")
```

## Host Harness Shape

Use `build-for-testing` once, then start one `xcodebuild test-without-building` process per physical device.

```text
resolve devices
verify device readiness
build-for-testing
resolve .xctestrun
resolve XCUITest runner bundle id

start peer alpha xcodebuild test-without-building in background
wait_for_log_marker(peer-alpha.log, "peer_alpha_ready")

start peer beta xcodebuild test-without-building in background

while either process is running:
  scan peer-a log for new APP_E2E_MARKER lines
  copy each new peer-a marker into peer-b runner container
  scan peer-b log for new APP_E2E_MARKER lines
  copy each new peer-b marker into peer-a runner container
  fail early if a process exits before required markers appear

wait for both processes
collect xcresults, logs, marker bridge log, screenshots
```

The log wait should fail with context:

```bash
wait_for_log_marker() {
  local log_file="$1"
  local marker="$2"
  local timeout_seconds="$3"
  local deadline=$((SECONDS + timeout_seconds))

  while [ "$SECONDS" -lt "$deadline" ]; do
    if rg -q "APP_E2E_MARKER ${marker}" "$log_file"; then
      return 0
    fi
    sleep 1
  done

  tail -n 120 "$log_file" >&2
  return 1
}
```

Track copied markers in the bridge to avoid duplicate copies:

```text
marker-bridge.log
  peer-a -> peer-b peer_beta_lookup_started copied
  peer-b -> peer-a peer_alpha_ready copied
```

Patch the `.xctestrun` only when the harness needs per-device environment, launch arguments, or result bundle paths. Keep the patched copies under the run directory.

## Screenshot And Snapshot Evidence

For physical multi-device e2e, use screenshots as evidence snapshots. Capture them at the same semantic boundaries as markers:

- test launch and initial screen
- role entered, for example an observing mode or peer lookup
- peer discovered
- peer still visible after a stability wait
- project-specific request sent
- project-specific request received
- ready/ack state
- confirmation submitted
- result screen visible
- cleanup or terminal error state

Rules:

- Add screenshots before and after important marker writes when the UI can change quickly.
- Add a screenshot immediately before a long wait and immediately after it unblocks.
- If a test fails on a wait, attach the current app screenshot before failing.
- Extract screenshots from every `.xcresult` after the run and visually inspect the last state before changing waits or queries.
- Keep screenshots from both devices; one side alone is usually insufficient for diagnosing synchronization failures.

Automated golden snapshot tests are a separate layer. Use `swift-snapshot-testing` for deterministic component or screen regressions, not for synchronizing physical BLE runs. For a physical e2e run, keep the extracted XCUITest screenshots as run evidence, and use snapshot diffs only when the same screen is also covered by a deterministic snapshot suite.

## Artifacts To Keep

Create a task-scoped run directory:

```bash
RUN_DIR=.temp/<task-id>/physical-ios-ios-e2e-$(date +%Y%m%d-%H%M%S)
mkdir -p "$RUN_DIR"
```

Keep:

- `peer-a-xcodebuild.log`
- `peer-b-xcodebuild.log`
- `marker-bridge.log`
- patched `.xctestrun` files, if generated
- `peer-a.xcresult`
- `peer-b.xcresult`
- extracted screenshots for both peers
- device readiness JSON/log files
- app install or launch JSON/log files when the harness installs or launches directly

Record the run directory in the task board, worklog, or durable research artifact. Do not keep the only explanation in chat.

## Common Mistakes

- Do not coordinate with fixed sleeps. Use stdout markers, marker files, and UI state waits.
- Do not copy marker files into the product app container unless the product app reads them.
- Do not wait for a peer marker before the other runner process has started and installed its container.
- Do not assume the runner bundle id. Resolve it from the `.xctestrun` or make it an explicit harness parameter.
- Do not let a short XCUITest method be the only thing keeping a long-running product role alive. Use a normal app process for long roles when XCTest teardown would close the app.
- Do not treat a text log as the source of truth for UI state. Inspect the screenshots in the `.xcresult`.
