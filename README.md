# UITestToolkit

Swift package for iOS/macOS UI testing with screenshot capture and validation.

## Products

| Product | Type | Description |
|---------|------|-------------|
| **ScreenshotKit** | Library | Screenshot capture with structured naming |
| **UITestKit** | Library | Page Object protocols, XCUIElement extensions, Allure annotations |
| **extract-screenshots** | CLI | Extract/organize screenshots from xcresult (macOS only) |
| **snapshotsdiff** | CLI | Create visual diffs between snapshot images (macOS only) |

> **Note:** Only add `ScreenshotKit` and `UITestKit` to your UI test target. The CLI tools use `Foundation.Process`/`AppKit` which are unavailable on iOS — do NOT add them as target dependencies. Run from terminal only.

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
        .product(name: "UITestKit", package: "UITestToolkit")
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

## Scripts

| Script | Description |
|--------|-------------|
| `check-tools.sh` | Verify Xcode, Swift, simctl installed |
| `run-tests-and-extract.sh` | Run UI tests + extract screenshots |
| `extract-screenshots.sh` | Extract screenshots from xcresult |
| `setup-project-skills.sh` | Install AI skill to a project |
| `setup-global-skills.sh` | Install AI skill globally |

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

## Project Structure

```
agents/skills/                     ← source of truth (visible in Finder)
  ios-ui-validation/               ← AI skill for UI testing
.claude/skills → ../agents/skills  ← symlink for Claude Code
.codex/skills → ../agents/skills   ← symlink for Codex CLI
```

All skills live in `agents/skills/`. The `.claude/` and `.codex/` folders are symlinks, so both Claude Code and Codex CLI find the same skills.

## AI Agent Skill

Includes `ios-ui-validation` skill for AI-assisted UI test development.

**Setup:**
```bash
./Scripts/setup-project-skills.sh /path/to/your/project  # project-local
./Scripts/setup-global-skills.sh                          # global
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

See the `ios-ui-validation` skill documentation for detailed patterns and examples.

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

See `ios-ui-validation` skill for detailed examples.

## Requirements

- iOS 15.0+ / macOS 13.0+
- Swift 6.2+
- Xcode 26+

Run `./Scripts/check-tools.sh` to verify.
