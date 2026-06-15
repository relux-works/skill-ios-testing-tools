# UITestToolkit

Swift package for iOS/macOS UI testing with screenshot capture and validation.

## Products

| Product | Type | Description |
|---------|------|-------------|
| **ScreenshotKit** | Library | Screenshot capture with structured naming |
| **UITestKit** | Library | Page Object protocols, XCUIElement extensions, Allure annotations |
| **IOSE2EPeerClient** | Library | Reusable UI test peer client for generalized E2E coordinator sessions |
| **extract-screenshots** | CLI | Extract/organize screenshots from xcresult (macOS only) |
| **snapshotsdiff** | CLI | Create visual diffs between snapshot images (macOS only) |
| **ios-device-build** | CLI | Build an iOS app across connected physical devices and the Apple Silicon Mac iOS-app destination (macOS only) |
| **ios-e2e-runner** | CLI | Coordinate generalized multi-peer iOS UI E2E sessions (macOS only) |
| **e2e-fake-peer** | CLI | Local sample peer for coordinator smoke tests (macOS only) |
| **e2e-listener-fake-peer** | CLI | Local sample peer for peer-listener transport smoke tests (macOS only) |

> **Note:** Add `ScreenshotKit` and `UITestKit` for standard UI testing. Add `IOSE2EPeerClient` only to UI test targets that participate in generalized E2E coordinator sessions. The CLI tools use `Foundation.Process`/`AppKit` which are unavailable on iOS — do NOT add them as target dependencies. Run from terminal only.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ivalx1s/swift-ui-testing-tools", from: "1.0.0")
    // or local: .package(path: "../swift-ui-testing-tools")
]
```

Add to UI test target:

```swift
.testTarget(
    name: "YourAppUITests",
    dependencies: [
        .product(name: "ScreenshotKit", package: "UITestToolkit"),
        .product(name: "UITestKit", package: "UITestToolkit"),
        // Optional for generalized multi-peer E2E tests:
        // .product(name: "IOSE2EPeerClient", package: "UITestToolkit")
    ]
)
```

## Usage

```swift
import XCTest
import ScreenshotKit
import UITestKit

final class MyUITests: BaseUITestSuite {

    override class func setUp() {
        super.setUp()
        ScreenshotManager.shared.startSession()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        startTestScreenshots()
    }

    @MainActor
    func testLogin() throws {
        let app = XCUIApplication()
        app.launch()
        screenshot(step: 1, "app_launched", app: app)

        app.textFields["username"].tap()
        app.textFields["username"].typeText("test@example.com")
        screenshot(step: 2, "username_entered", app: app)

        app.buttons["Login"].tap()

        XCTAssertTrue(app.staticTexts["Welcome"].waitFor(\.exists, toBe: true, timeout: 5))
        screenshot(step: 3, "login_success", app: app)
    }
}
```

## Test Platform Selection

Choose the execution platform from the target declaration before running tests.

- iOS app target or app package: run tests and runtime by default on iOS Simulator.
- App target or app package on another declared platform: run against that declared platform.
- If the app/package declares no platform, default to macOS.
- Package module or multi-platform package: run unit and integration tests on macOS when macOS is supported.
- If macOS is unavailable, prefer iOS when declared.
- Otherwise use the first declared platform.
- Use simulator destinations only for iOS-family runs. For macOS, run on macOS directly.
- If a reusable iOS package is consumed through an app-local graph and standalone package schemes cannot resolve local dependencies, verify it through the app workspace/test host instead of treating the standalone package build as the product build.

### Apple Silicon Mac iOS-App Runtime

When an iOS app needs a Mac-side endpoint, use the existing iPhoneOS app on the Apple Silicon Mac `Designed for iPad/iPhone` destination. Do not add a separate macOS app target unless the product explicitly needs native macOS UI.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -workspace App.xcworkspace \
  -scheme App \
  -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
  build
```

Launching the built `Debug-iphoneos/App.app` with `open` is not reliable for this runtime, and XCUITest cannot drive `My Mac (Designed for iPad)`. Use Xcode's run action through AppleScript to launch the Mac-hosted iOS app, then run the actual UI test against a physical iPhone or Simulator endpoint. See `agents/skills/ios-testing-tools/SKILL.md` for the full workflow.

## Connected Device Builds

Use `ios-device-build` when a project needs one command that builds an iOS app for every currently discovered physical iPhone/iPad. The command discovers devices through `xcrun xcdevice list --json`; there is no hard-coded expected device list, so a missing device is skipped and the remaining devices still build. If no matching destinations are found, the command fails.

The build contract is intentionally explicit. Pass the project source, scheme, discovery interfaces, target set, and DerivedData/log root every time. The CLI fails fast on missing required parameters instead of guessing.

Discovery is an interface option set:

- `--discovery usb` builds only cable-connected physical iOS devices. This is the preferred stable mode.
- `--discovery wifi` builds only network-discovered physical iOS devices.
- `--discovery usb,wifi` builds every available physical iOS device Xcode currently sees.

Target selection is separate:

- `--targets iphones` builds physical iOS devices.
- `--targets macbook` builds the Apple Silicon Mac `Designed for iPad/iPhone` destination when Xcode exposes it.
- `--targets iphones,macbook` builds both groups.

```bash
./Scripts/ios-device-build.sh \
  --workspace App.xcworkspace \
  --scheme App \
  --discovery usb \
  --targets iphones \
  --derived-data-root .temp/device-builds
```

```bash
./Scripts/ios-device-build.sh \
  --project App.xcodeproj \
  --scheme App \
  --discovery usb,wifi \
  --targets iphones \
  --derived-data-root .temp/device-builds
```

```bash
./Scripts/ios-device-build.sh \
  --workspace App.xcworkspace \
  --scheme App \
  --discovery usb \
  --targets iphones,macbook \
  --mac-destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
  --derived-data-root .temp/device-builds
```

```bash
./Scripts/ios-device-build.sh \
  --workspace App.xcworkspace \
  --scheme App \
  --targets macbook \
  --mac-destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
  --derived-data-root .temp/device-builds
```

Per-destination DerivedData and `xcodebuild.log` files are written under the required `--derived-data-root`.

## iOS E2E Runner

Use `ios-e2e-runner` to validate and run generalized multi-peer iOS UI E2E sessions. The runner config is project-neutral: product repositories provide peer mappings, Xcode destinations, selectors, and scenario event names in their own config or test code.

Dry-run validates the config and prints the exact peer launch plan without building, installing, launching devices, or starting UI tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift run ios-e2e-runner \
  --config Samples/IOSE2ECoordinator/dry-run-two-peer.yaml \
  --dry-run \
  --session-id sample-session
```

The runner injects reserved `E2E_*` environment values into every peer process so UI tests can connect to the coordinator through `IOSE2EPeerClient`.

Physical devices must be able to open TCP connections to the coordinator host. When all peers share the same LAN route, set `coordinator.advertisedHost` once. When peers need different routes to the same coordinator, for example separate wired or lab-network interfaces, set `coordinatorHost` on the individual peer; the runner keeps the global coordinator bind/port/path and injects a peer-specific `E2E_COORDINATOR_URL`.

```yaml
peers:
  - name: peer-a
    coordinatorHost: 192.168.50.10
    launch:
      kind: xctest
      startWhen:
        type: immediate
```

Build the local sample peer before running the process-peer sample:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift build --product e2e-fake-peer
```

Then run the three-peer local sample:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
./Scripts/run-e2e-sample-smoke.sh
```

### Peer-Listener Transport

Use `coordinator.transport: peer-listener` when physical iOS peers cannot reach a Mac-hosted WebSocket coordinator directly. In this mode each UI test peer starts a device-side TCP listener, the Mac runner starts `iproxy` for each connected device, and the Mac-side coordinator connects to every peer through the forwarded localhost ports.

Consumer UI tests should import `IOSE2EPeerClient` and use `UITestE2EClient.fromEnvironment()`. Do not import `IOSE2ECoordinatorCore` from product tests just to inspect peer names; use `client.environment.peerNameValue` for project scenario branching.

```yaml
coordinator:
  transport: peer-listener

peers:
  - name: peer-a
    connection:
      listenPort: 19131
      connectHost: 127.0.0.1
      connectPort: 18131
      proxy:
        kind: iproxy
        udid: 00000000-0000000000000000
```

Run the toolkit-local smoke:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
./Scripts/run-e2e-peer-listener-sample-smoke.sh
```

## Physical Device Runtime Logs

When debugging runtime behavior on a physical iPhone, prefer the live device console over guessing from `xcodebuild` output.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun xcdevice list
```

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun devicectl device process launch \
  --device <device-udid> \
  --terminate-existing \
  --console \
  <bundle-id>
```

Use `--console` for app-scoped logs, `--terminate-existing` to avoid stale processes, and the device UDID rather than the display name.

## Scripts

| Script | Description |
|--------|-------------|
| `check-tools.sh` | Verify required tools, plus optional iOS Simulator support |
| `run-tests-and-extract.sh` | Run UI tests + extract screenshots |
| `extract-screenshots.sh` | Extract screenshots from xcresult |
| `ios-device-build.sh` | Build an iOS app across discovered physical devices and optional Mac-compatible iOS destination |
| `run-e2e-sample-smoke.sh` | Build the fake peer, run the local three-peer coordinator sample, and validate artifacts |
| `run-e2e-peer-listener-sample-smoke.sh` | Build the listener fake peer, run the local peer-listener coordinator sample, and validate artifacts |
| `ios-e2e-runner` | SwiftPM executable for generalized multi-peer E2E dry-run and execution |
| `e2e-fake-peer` | SwiftPM executable used by local coordinator samples |
| `e2e-listener-fake-peer` | SwiftPM executable used by local peer-listener samples |
| `setup.sh` | Canonical global skill install into `~/.agents` |
| `setup-project-skills.sh` | Install AI skill to a project-local `.agents` |
| `setup-global-skills.sh` | Compatibility wrapper around `./setup.sh` |

```bash
# Check prerequisites
./Scripts/check-tools.sh

# Run tests and extract screenshots (run from your project directory!)
cd /path/to/your/project
~/src/swift-ui-testing-tools/Scripts/run-tests-and-extract.sh \
  -workspace App.xcworkspace \
  -scheme App \
  -output .temp/screenshots
```

Options:
- `-output dir` — where to put screenshots (default: `.temp/{timestamp}_screenshots`, relative to CWD)
- `-destination "..."` — simulator to use (default: iPhone 16)

The simulator examples above are for iOS app/UI-test flows. Package module unit and integration tests should stay on macOS when macOS is supported by the package.

## Project Structure

```
agents/skills/                        ← source repo content
  ios-testing-tools/                  ← source skill
~/.agents/skills/ios-testing-tools/   ← global installed runtime copy
<project>/.agents/skills/ios-testing-tools/  ← project-local installed runtime copy
.claude/skills → ../.agents/skills    ← symlink for Claude Code
.codex/skills → ../.agents/skills     ← symlink for Codex CLI
```

Source content lives in `agents/skills/`. Installed runtime copies live in `~/.agents/skills/` or `<project>/.agents/skills/`, and those copies are degitized after sync. `.claude/` and `.codex/` only point at the installed copy.

## AI Agent Skill

Includes `ios-testing-tools` skill for AI-assisted UI test development.

**Setup:**
```bash
./setup.sh                                               # canonical global install
./Scripts/setup-project-skills.sh /path/to/your/project  # project-local install
./Scripts/setup-global-skills.sh                         # compatibility wrapper
```

**Provides:**
- Page Object pattern templates
- Accessibility ID naming conventions (BEM-like)
- Shared identifiers setup (app + test targets)
- Screenshot workflow with verification
- Snapshot testing with swift-snapshot-testing
- Allure integration (optional)

## Snapshot Testing

For automated UI regression testing, use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing).

Add to your snapshot test target:

```swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
]
```

See the `ios-testing-tools` skill documentation for detailed patterns and examples.

## snapshotsdiff CLI

Create visual diffs between snapshot images:

```bash
# Compare two images
swift run snapshotsdiff reference.png failed.png diff.png

# Batch compare all failed snapshots
swift run snapshotsdiff \
  --artifacts ./SnapshotArtifacts \
  --output ./SnapshotDiffs \
  --tests ./AppSnapshotTests
```

Output for batch mode:

```
SnapshotDiffs/
  TestName/
    snapshotName/
      ├── reference.png   (expected)
      ├── failed.png      (actual)
      └── diff.png        (visual diff)
```

## CI/CD Integration

### GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - build_and_test
  - generate_snapshot_diffs

variables:
  SNAPSHOT_ARTIFACTS: "$CI_PROJECT_DIR/SnapshotArtifacts"
  SNAPSHOT_DIFFS: "$CI_PROJECT_DIR/SnapshotDiffs"
  SNAPSHOT_TESTS: "$CI_PROJECT_DIR/AppSnapshotTests"

build_and_test:
  stage: build_and_test
  script:
    - bundle exec fastlane build_and_test
  artifacts:
    when: always
    paths:
      - $SNAPSHOT_ARTIFACTS
    expire_in: 1 day

generate_snapshot_diffs:
  stage: generate_snapshot_diffs
  dependencies:
    - build_and_test
  script:
    - |
      if [ -d "$SNAPSHOT_ARTIFACTS" ] && [ "$(ls -A $SNAPSHOT_ARTIFACTS)" ]; then
        swift run --package-path /path/to/swift-ui-testing-tools snapshotsdiff \
          --artifacts "$SNAPSHOT_ARTIFACTS" \
          --output "$SNAPSHOT_DIFFS" \
          --tests "$SNAPSHOT_TESTS"
      fi
  artifacts:
    when: always
    paths:
      - $SNAPSHOT_DIFFS
    expire_in: 1 week
```

### GitHub Actions

```yaml
# .github/workflows/snapshot-tests.yml
name: Snapshot Tests
on:
  pull_request:

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: xcodebuild test -scheme AppSnapshotTests -destination "platform=iOS Simulator,name=iPhone 16" || true
      - name: Generate diffs
        run: |
          git clone https://github.com/user/swift-ui-testing-tools.git /tmp/toolkit
          if [ -d "SnapshotArtifacts" ]; then
            swift run --package-path /tmp/toolkit snapshotsdiff \
              --artifacts ./SnapshotArtifacts --output ./SnapshotDiffs --tests ./AppSnapshotTests
          fi
      - uses: actions/upload-artifact@v4
        with:
          name: snapshot-diffs
          path: SnapshotDiffs/
```

### Fastlane

```ruby
# fastlane/Fastfile
lane :generate_snapshot_diffs do
  artifacts = ENV['SNAPSHOT_ARTIFACTS']
  return unless File.directory?(artifacts) && !Dir.empty?(artifacts)

  sh("swift run --package-path ../swift-ui-testing-tools snapshotsdiff " \
     "--artifacts #{artifacts} --output #{ENV['SNAPSHOT_DIFFS']} --tests #{ENV['SNAPSHOT_TESTS']}")
end
```

See `ios-testing-tools` skill for detailed examples.

## Requirements

- iOS 15.0+ / macOS 13.0+
- Swift 6.2+
- Xcode 26+

Run `./Scripts/check-tools.sh` to verify.
