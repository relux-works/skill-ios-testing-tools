---
name: ios-testing-tools
description: |
  iOS UI testing toolkit with screenshot validation. Use when:
  (1) Setting up UI test infrastructure with Page Object pattern
  (2) Creating accessibility identifiers with structured naming
  (3) Writing UI tests with step-by-step screenshots
  (4) Validating UI via screenshot comparison
  (5) Writing snapshot tests with swift-snapshot-testing
  (6) Comparing snapshot diffs with snapshotsdiff CLI
  (7) Integrating with Allure for test reporting
  (8) Organizing shared test identifiers between app and test targets
  File types: Swift UI tests, XCUITest, xcresult, Allure reports, snapshot tests
---

# iOS UI Validation

Write UI, add UI tests with structured markup, validate via screenshots.

> **Repository:** [swift-ui-testing-tools](https://github.com/ivalx1s/swift-ui-testing-tools)
>
> **Before using this skill, check for updates:**
> ```bash
> cd ~/src/swift-ui-testing-tools && git pull
> ```

## Prerequisites

**Before starting, verify required tools are installed:**

```bash
./Scripts/check-tools.sh
```

Required:
- Xcode Command Line Tools (`xcodebuild`, `xcrun`, `xcresulttool`)
- Swift 5.9+
- iOS Simulator with available devices when the selected test platform is iOS

## Test Platform Selection

Pick the execution platform from the target declaration before running anything.

- iOS app target or app package: run tests and runtime by default on iOS Simulator.
- App target or app package on another declared platform: run against that declared platform.
- If the app/package does not declare any platform, default to macOS.
- Package module or multi-platform package: run unit and integration tests on macOS when macOS is supported.
- If macOS is not supported, prefer iOS when iOS is declared.
- If neither macOS nor iOS is available, use the first declared platform.
- Use simulator destinations only for iOS-family runs. For macOS, run on macOS directly.

## Apple Silicon Mac iOS-App Runtime

Use this path when the product app is an iOS app and the test environment needs a Mac-side peer, receiver, or host process on Apple Silicon. This is **not** a separate macOS app target and not Catalyst. It is the existing iPhoneOS app running on the Mac as `Designed for iPad/iPhone`.

First verify that Xcode exposes the destination:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -workspace App.xcworkspace \
  -scheme App \
  -showdestinations
```

Look for a destination like:

```text
{ platform:macOS, arch:arm64, variant:Designed for [iPad,iPhone], name:My Mac }
```

Build the existing iOS app for that destination:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -workspace App.xcworkspace \
  -scheme App \
  -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
  build
```

Important limitations:

- Do not create a separate macOS app target just to get a Mac-side peer. Use the existing iOS app on the Apple Silicon Mac destination unless the product explicitly needs native macOS UI.
- `open Debug-iphoneos/App.app` is not a valid launch path for this runtime. macOS may report `incorrect executable format` because the product is still an iPhoneOS bundle.
- `devicectl` targets physical devices; it does not reliably expose the Apple Silicon Mac `Designed for iPad` runtime as an install/launch device.
- XCUITest cannot drive the Mac `Designed for iPad` destination. `xcodebuild test` can fail with `UI tests are not supported on My Mac (Designed for iPad)`.

To launch the Mac-hosted iOS app from automation, ask Xcode to run the scheme through AppleScript. This uses the same run machinery as pressing Run in Xcode:

```bash
osascript <<'APPLESCRIPT'
set workspacePath to POSIX file "/absolute/path/App.xcworkspace"
tell application "Xcode"
    activate
    open workspacePath
    set workspaceDocument to workspace document "App.xcworkspace"
    repeat 120 times
        if loaded of workspaceDocument is true then exit repeat
        delay 0.5
    end repeat
    if loaded of workspaceDocument is false then error "Xcode workspace did not finish loading"
    set actionResult to debug workspaceDocument scheme "App" run destination specifier "platform=macOS,arch=arm64,variant=Designed for iPad" skip building true
    return id of actionResult
end tell
APPLESCRIPT
```

Stop the running action when the test environment is done:

```bash
osascript <<'APPLESCRIPT'
tell application "Xcode"
    set workspaceDocument to workspace document "App.xcworkspace"
    stop workspaceDocument
end tell
APPLESCRIPT
```

For cross-runtime e2e, run the Mac-hosted iOS app as one endpoint, then run the actual XCUITest against the physical iPhone or Simulator endpoint:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -workspace App.xcworkspace \
  -scheme AppUITests \
  -destination 'id=<physical-device-udid>' \
  -only-testing:AppUITests/SomeE2ETests/testPhoneSeesMacHostedPeer \
  test
```

Keep screenshots and assertions on the XCTest-driven endpoint. For the Mac-hosted iOS app, rely on app automation configuration, process checks, Xcode action status, logs, or manual permission approval when the OS prompts for Bluetooth, Local Network, or similar privacy access.

## Physical Device Runtime Logs

When UI tests or runtime behavior are investigated on a physical iPhone, inspect the live device console instead of guessing from `xcodebuild` output alone.

- Prefer `devicectl device process launch --console` for app-scoped runtime logs on a connected device.
- Always set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` before `xcrun` commands if the shell does not already point at Xcode.
- Resolve the target device first with `xcrun xcdevice list`.
- Use the device UDID in commands; names can be ambiguous.

Recommended flow:

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

Notes:
- `--console` attaches stdout/stderr and waits for app exit, so use it for live runtime triage.
- `--terminate-existing` avoids reading stale logs from an older app process.
- This is the preferred path for investigating auth/network/runtime failures on device.
- If you need broader system logs beyond one app process, fall back to Xcode Devices window or Console.app with the same physical device selected.

## Physical Device Tunnel Recovery

Use this playbook when Xcode or `devicectl` can see a physical iPhone, pairing succeeds, but developer operations fail with a tunnel error such as:

```text
The tunnel connection failed while the system tried to connect to the device.
Domain: com.apple.dt.CoreDeviceError
Code: 4
--
Domain: com.apple.dt.RemotePairingError
Code: 4
```

Typical `devicectl device info details` symptoms:

- `pairingState: paired`
- `transportType: wired` or `localNetwork`
- `tunnelState: disconnected`
- `ddiServicesAvailable: false`
- `devicectl device info lockState --device <udid>` fails with `RemotePairingError Code=4`

First collect the state and compare with a known-good physical device if one is attached:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun xcdevice list

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun devicectl list devices

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun devicectl device info details \
  --device <device-udid> \
  --verbose \
  --timeout 30 \
  --json-output .temp/device-details.json \
  --log-output .temp/device-details.log

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun devicectl device info lockState \
  --device <device-udid> \
  --verbose \
  --timeout 30 \
  --json-output .temp/device-lockstate.json \
  --log-output .temp/device-lockstate.log
```

If the device charges but does not appear in `ioreg`, the Mac only sees power, not the USB data interface. Reboot the iPhone, unlock it, reconnect a known-good data cable/port, and accept the Trust prompt before spending time on Xcode caches:

```bash
ioreg -p IOUSB -l -w 0 | rg "USB Serial Number|<device-udid-without-dashes>"
```

If USB data and pairing are present but the tunnel still fails, use the iPhone-side Developer networking reset before clearing host caches:

1. On the iPhone, open `Settings -> Developer -> Networking`.
2. Enable `Network Link Conditioner`.
3. If present, enable `Network Override`; it may be absent on some iPhone/iOS builds.
4. Open `Responsiveness`.
5. Run `Test Responsiveness` and wait for it to finish.
6. Retry `devicectl device info lockState --device <device-udid>`.

This can recover a stale Developer networking stack without rebooting, unpairing, or resetting trusted computers. A successful recovery usually changes `details` to:

- `tunnelState: connected`
- `ddiServicesAvailable: true`
- `developerModeStatus: enabled`
- a non-empty `tunnelIPAddress`

If the issue persists after the Responsiveness test:

- Disable `Multipath Networking` in `Settings -> Developer` if the setting exists.
- Check for host VPN or network filter interfaces with `scutil --nwi` and `ifconfig | rg "utun|ipsec|tap|tun"`.
- Restart CoreDevice host services and retry:

```bash
killall CoreDeviceService remoted 2>/dev/null || true

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun devicectl manage ddis update --verbose --timeout 120
```

- If the iPhone OS is newer than the installed Xcode support, install a matching Xcode/device support bundle before continuing.
- Only then consider heavier steps such as unpairing, resetting Location & Privacy/trusted computers, deleting Xcode/CoreDevice caches, or rebooting the Mac.

## Main Workflow

1. **Write UI** with accessibility identifiers
2. **Write UI tests** using Page Object pattern
3. **Capture screenshots** at each step
4. **Extract and review** screenshots to verify UI looks as expected
5. **MANDATORY: Visually verify screenshots** - open and check that UI is rendered correctly

## CRITICAL: Screenshot Verification

After extracting screenshots, **ALWAYS open and visually inspect them** using the Read tool. Check for:

- **Orientation issues** - UI should not be rotated/sideways
- **Layout problems** - UI elements should be visible and properly positioned, not squished in corners
- **Content visibility** - all expected UI elements should be present and readable
- **Black screens** - indicates app didn't launch or UI didn't render

Common issues and fixes:
- **Rotated UI in landscape frame**: Force portrait in PageManager: `XCUIDevice.shared.orientation = .portrait`
- **Empty/black screenshots**: Check app launch, add delays if needed
- **Partial UI**: Scroll or adjust viewport before screenshot

## Core Components

### 1. UITestToolkit Package

SPM package providing:
- **ScreenshotKit** - capture screenshots with structured naming
- **UITestKit** - common UI test utilities:
  - `PageObject/` - PageElement, ComponentElement protocols, BaseUITestSuite
  - `Extensions/` - XCUIElement+WaitFor helper
  - `Allure/` - AllureTrackable protocol for Allure annotations
- **extract-screenshots** - macOS CLI to extract/organize screenshots from xcresult

Add as SPM dependency (local or remote).

**Important:** Only add `ScreenshotKit` and `UITestKit` to UI test target dependencies. Do NOT add `extract-screenshots` — it uses `Foundation.Process` (unavailable on iOS) and will fail to build for iOS Simulator. Run it from terminal only.

### 2. Accessibility ID System

BEM-like naming. See [references/accessibility-ids.md](references/accessibility-ids.md).

Pattern: `{Module} {Screen} {Element} {Action/State}`

```swift
"Auth initial Login button"
"Auth pin wall Create pin page"
```

### 3. Shared Identifiers (TestEnvShared)

Share IDs between app and test targets. See [references/shared-identifiers.md](references/shared-identifiers.md).

Template: `assets/TestEnvShared/`. Add to both main app and UI test targets.

### 4. Page Object Pattern

UI test structure. See [references/page-object-pattern.md](references/page-object-pattern.md).

Template: `assets/UIStruct/`. Copy to UI test target.

### 5. Allure Integration (Optional)

Only if project uses Allure TestOps. See [references/allure-integration.md](references/allure-integration.md).

Allure annotations are included in **UITestKit** (`Allure/AllureTrackable.swift`).

## Quick Start

### 1. Setup

```bash
# Copy TestEnvShared templates (shared between app and tests)
cp -r assets/TestEnvShared/ ./TestEnvShared/

# Copy UIStruct to UI test target (Page Objects)
cp -r assets/UIStruct/ ./AppUITests/UIStruct/
```

Add to Xcode:
- **UITestToolkit** as SPM dependency (local clone or git URL)
- **TestEnvShared** to both app and test target compile sources
- **ScreenshotKit + UITestKit** as dependencies to UI test target (NOT extract-screenshots!)

### 2. Mark UI Elements

```swift
// In SwiftUI
Button("Login") { ... }
    .accessibilityIdentifier(UITest.Identifier.Auth.Initial.login_btn)

// In UIKit
button.accessibilityIdentifier = UITest.Identifier.Auth.Initial.login_btn
```

### 3. Define Identifiers

```swift
// TestEnvShared/UITest/UITest+Identifiers.swift
extension UITest.Identifier {
    enum Auth {
        enum Initial {
            static let login_btn = "Auth initial Login button"
        }
    }
}
```

### 4. Create Page Object

```swift
// UIStruct/Pages/Auth/UITest+Page+Auth+Initial.swift
extension UITest.Page.Auth {
    struct Initial: UITest.PageElement {
        private let loginButton: XCUIElement

        init(app: XCUIApplication) {
            self.loginButton = app.buttons[UITest.Identifier.Auth.Initial.login_btn]
        }

        func waitForAppear() {
            XCTAssert(loginButton.waitForExistence(timeout: 5))
        }

        func tapLogin() {
            loginButton.tap()
        }
    }
}
```

### 5. Write Test with Screenshots

```swift
import XCTest
import ScreenshotKit
import UITestKit

final class AuthTests: BaseUITestSuite, AllureTrackable {
    override class func setUp() {
        super.setUp()
        ScreenshotManager.shared.startSession()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        startTestScreenshots()
    }

    func testLoginFlow() throws {
        let pm: UITest.PageManager = .init()

        pm.authInitial.waitForAppear()
        screenshot(step: 1, "login_screen", app: pm.app)

        pm.authInitial.tapLogin()
        screenshot(step: 2, "after_login_tap", app: pm.app)

        pm.mainScreen.waitForAppear()
        screenshot(step: 3, "main_screen_visible", app: pm.app)
    }
}
```

### 6. Run and Extract Screenshots

**After EVERY test run, extract screenshots to `.temp/` (gitignored).**

**IMPORTANT: Run from your project directory** so screenshots land in your project's `.temp/`, not the toolkit's.

**Option A: One command (recommended)**

These simulator examples are for iOS app/UI-test flows. For package module unit/integration tests, apply the platform-selection rule above first and stay on macOS when supported.

```bash
# Run from YOUR PROJECT directory (not toolkit directory!)
cd /path/to/your/project

# Path to toolkit (adjust as needed)
TOOLKIT=~/src/swift-ui-testing-tools

# Run tests and extract — output goes to .temp/ of current directory
$TOOLKIT/Scripts/run-tests-and-extract.sh \
  -workspace App.xcworkspace \
  -scheme App \
  -output .temp/screenshots

# With custom simulator:
$TOOLKIT/Scripts/run-tests-and-extract.sh \
  -workspace App.xcworkspace \
  -scheme App \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
  -output .temp/screenshots
```

Options:
- `-output dir` — where to put screenshots (default: `.temp/{timestamp}_screenshots`)
- `-destination "..."` — simulator to use (default: iPhone 16)

**Option B: Manual steps**

```bash
# Run from your project directory
cd /path/to/your/project

# Run tests (xcresult goes to .temp/)
xcodebuild test \
  -workspace App.xcworkspace \
  -scheme App \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -resultBundlePath .temp/latest.xcresult

# Extract screenshots to .temp/
swift run --package-path ~/src/swift-ui-testing-tools \
  extract-screenshots .temp/latest.xcresult .temp/screenshots
```

**MANDATORY: Always extract screenshots after test run.** Don't skip this step.

### 7. Review Screenshots (MANDATORY)

```
.temp/screenshots/                          # if -output .temp/screenshots
  Run_2026-01-16_12-38-13/
    Test_testLoginFlow/
      Step_01__18-12-25-546__login_screen.png
      Step_02__18-12-26-016__after_login_tap.png
      Step_03__18-12-26-591__main_screen_visible.png
```

**ALWAYS visually open and inspect screenshots** using the Read tool. Verify:
- UI is not rotated or sideways
- All elements are visible and properly laid out
- No black screens or rendering issues
- Content matches expected state for each step

If screenshots show orientation/layout issues, fix PageManager orientation setting and re-run tests.

## Screenshot Naming

Format: `Run_{session}__Test_{name}__Step_{NN}__{timestamp}__{description}`

| Part | Example | Description |
|------|---------|-------------|
| session | `2026-01-15_18-12-22` | Test run start |
| name | `testLoginFlow` | Test method |
| NN | `01` | Step number |
| timestamp | `18-12-25-546` | Capture time |
| description | `login_screen` | Your description |

## UI Element State Verification

**Use `waitFor` helper instead of sleep/delay.** Never use `Thread.sleep` for UI state changes.

The `waitFor` extension is included in **UITestKit** (`Extensions/XCUIElement+WaitFor.swift`).

### Usage

```swift
// Wait for label to change
XCTAssertTrue(element.waitFor(\.label, toBe: "Expected", timeout: 3))

// Wait for switch state
XCTAssertTrue(toggle.waitFor(\.stringValue, toBe: "1", timeout: 3)) // "1" = on, "0" = off
```

## SwiftUI Toggle Interaction

**SwiftUI Toggle in Form/List requires coordinate-based tap.** Standard `.tap()` hits the label, not the switch control.

```swift
func toggleDebugMode() {
    // Tap on the right side where the switch control is located
    let coordinate = debugToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
    coordinate.tap()
}
```

This applies to any SwiftUI Toggle where the tap area includes the label.

## Snapshot Testing (swift-snapshot-testing)

For automated UI regression testing, use **snapshot tests** with [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) by PointFree.

Apply the same platform-selection rule here: iOS app snapshots default to iOS Simulator; library/module packages stay on macOS when macOS is supported.

### When to Use

- **XCUITest screenshots** — manual validation during development, step-by-step flow verification
- **Snapshot tests** — automated regression testing, CI/CD integration, comparing UI against reference images

### Setup

Add swift-snapshot-testing to your project:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
]

// Add to snapshot test target
.testTarget(
    name: "AppSnapshotTests",
    dependencies: [
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ]
)
```

### Snapshot Naming Convention (BEM-like)

Use the same BEM-like naming for snapshot tests:

```swift
// Pattern: {Module}_{Screen}_{State}
"Auth_Initial_Default"
"Auth_PinWall_CreatePin_3digits"
"Settings_Profile_DarkMode"
```

### Writing Snapshot Tests

Use **Swift Testing** framework (not XCTest):

```swift
import SnapshotTesting
import Testing
import SwiftUI
@testable import MyApp

@MainActor
@Suite
struct Auth_Initial_Page_SnapshotTests {

    @Test(arguments: [ViewImageConfig.iPhone13Pro, ViewImageConfig.iPhoneSe])
    func initialPage(_ device: ViewImageConfig) async throws {
        let view = Auth.UI.Initial.Page(actions: .mock)

        assertSnapshot(
            of: view.withSnapshotContext(),
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.98,
                layout: .device(config: device)
            ),
            named: device.sizeLabel,
            record: false  // Set to true to record new reference
        )
    }
}

// MARK: - Helpers

extension View {
    func withSnapshotContext(embedInNavigation: Bool = true) -> some View {
        Group {
            if embedInNavigation {
                NavigationStack { self }
            } else {
                self
            }
        }
        .transaction { $0.animation = .none }
    }
}

extension ViewImageConfig {
    var sizeLabel: String {
        guard let w = size?.width, let h = size?.height else { return "unknown" }
        return "\(Int(w))_\(Int(h))"
    }
}
```

### Key Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `precision` | 0.98 | % of pixels that must match exactly |
| `perceptualPrecision` | 0.98 | Perceptual similarity (98% ≈ human eye) |
| `layout` | `.device(config:)` | Device frame size |
| `named` | device label | Suffix for snapshot filename |
| `record` | false | Set true to record new reference |

### Snapshot Storage

Reference images are stored in `__Snapshots__` folders next to test files:

```
AppSnapshotTests/
  Auth/
    Auth_Initial_Page_Tests.swift
    __Snapshots__/
      Auth_Initial_Page_Tests/
        initialPage.390_844.png     # iPhone 13 Pro
        initialPage.320_568.png     # iPhone SE
```

### Test Case Patterns

For views with multiple states, use test case arrays:

```swift
@MainActor
@Suite
struct PinWall_SnapshotTests {

    struct TestCase {
        let name: String
        let props: PinLayout.Props
    }

    static let cases: [TestCase] = [
        .init(name: "create_pin_3digits", props: .createPin(digits: 3)),
        .init(name: "confirm_pin_empty", props: .confirmPin(digits: 0)),
        .init(name: "enter_pin_error", props: .enterPin(error: true))
    ]

    @Test(arguments: [ViewImageConfig.iPhone13Pro])
    func pinLayout(_ device: ViewImageConfig) async throws {
        for testCase in Self.cases {
            let view = PinLayout(props: testCase.props)

            assertSnapshot(
                of: view.withSnapshotContext(),
                as: .image(precision: 0.98, perceptualPrecision: 0.98, layout: .device(config: device)),
                named: testCase.name,
                record: false
            )
        }
    }
}
```

### Comparing Failed Snapshots (snapshotsdiff)

When snapshot tests fail, use **snapshotsdiff** CLI to create visual diffs:

```bash
# Compare two specific images
swift run --package-path ~/src/swift-ui-testing-tools \
  snapshotsdiff reference.png failed.png diff.png

# Batch compare all failed snapshots
swift run --package-path ~/src/swift-ui-testing-tools \
  snapshotsdiff \
    --artifacts ./SnapshotArtifacts \
    --output ./SnapshotDiffs \
    --tests ./AppSnapshotTests
```

Output structure for batch mode:

```
SnapshotDiffs/
  TestName/
    snapshotName/
      ├── reference.png   (expected)
      ├── failed.png      (actual)
      └── diff.png        (visual diff)
```

Diff visualization:
- **Different pixels**: highlighted with boosted color
- **Same pixels**: dimmed gray with transparency

### CI/CD Integration

#### GitLab CI Example

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
  tags:
    - ios
  script:
    - bundle exec fastlane build_and_test
  artifacts:
    when: always
    paths:
      - $SNAPSHOT_ARTIFACTS
    expire_in: 1 day
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'

generate_snapshot_diffs:
  stage: generate_snapshot_diffs
  tags:
    - ios
  dependencies:
    - build_and_test
  script:
    - |
      if [ -d "$SNAPSHOT_ARTIFACTS" ] && [ "$(ls -A $SNAPSHOT_ARTIFACTS)" ]; then
        echo "Found snapshot artifacts, generating diffs..."
        bundle exec fastlane generate_snapshot_diffs
      else
        echo "No snapshot artifacts found, skipping"
      fi
  artifacts:
    when: always
    paths:
      - $SNAPSHOT_DIFFS
    expire_in: 1 week
  when: always
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

#### Fastlane Lane

```ruby
# fastlane/Fastfile
desc "Build and test"
lane :build_and_test do
  run_tests(
    scheme: "MyApp",
    device: "iPhone 16",
    code_coverage: true
  )
end

desc "Generate snapshot diffs"
lane :generate_snapshot_diffs do
  artifacts = ENV['SNAPSHOT_ARTIFACTS']
  diffs = ENV['SNAPSHOT_DIFFS']
  tests = ENV['SNAPSHOT_TESTS']

  unless File.directory?(artifacts) && !Dir.empty?(artifacts)
    UI.important("No snapshot artifacts found, skipping")
    next
  end

  FileUtils.mkdir_p(diffs)

  # Path to UITestToolkit (clone or submodule)
  toolkit_path = "../swift-ui-testing-tools"

  sh("cd #{toolkit_path} && swift run snapshotsdiff " \
     "--artifacts \"#{artifacts}\" " \
     "--output \"#{diffs}\" " \
     "--tests \"#{tests}\"")

  if $?.success? && File.directory?(diffs) && !Dir.empty?(diffs)
    UI.success("Snapshot diffs generated: #{diffs}")
  else
    UI.important("No diffs generated (no differences found)")
  end
end
```

#### GitHub Actions Example

```yaml
# .github/workflows/snapshot-tests.yml
name: Snapshot Tests

on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      - name: Run snapshot tests
        run: |
          xcodebuild test \
            -scheme AppSnapshotTests \
            -destination "platform=iOS Simulator,name=iPhone 16" \
            -resultBundlePath TestResults.xcresult || true

      - name: Clone UITestToolkit
        if: always()
        run: git clone https://github.com/user/swift-ui-testing-tools.git /tmp/toolkit

      - name: Generate snapshot diffs
        if: always()
        run: |
          if [ -d "SnapshotArtifacts" ] && [ "$(ls -A SnapshotArtifacts)" ]; then
            swift run --package-path /tmp/toolkit snapshotsdiff \
              --artifacts ./SnapshotArtifacts \
              --output ./SnapshotDiffs \
              --tests ./AppSnapshotTests
          fi

      - name: Upload diffs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: snapshot-diffs
          path: SnapshotDiffs/
          retention-days: 7
```

#### Pipeline Flow

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  build_and_test │────▶│ generate_snapshot_   │────▶│  Review diffs   │
│                 │     │ diffs                │     │  in artifacts   │
│  - run tests    │     │                      │     │                 │
│  - save failed  │     │  - run snapshotsdiff │     │  reference.png  │
│    snapshots    │     │  - save diffs        │     │  failed.png     │
└─────────────────┘     └──────────────────────┘     │  diff.png       │
                                                     └─────────────────┘
```

#### Snapshot Artifacts Location

swift-snapshot-testing saves failed snapshots to a configurable location. Set via environment or test configuration:

```swift
// In test setUp
SnapshotTesting.diffTool = "ksdiff"  // optional: diff tool for local dev
SnapshotTesting.record = false

// Failed snapshots go to __Snapshots__ sibling folder by default
// Or configure custom path for CI artifacts
```
