# UITestToolkit

Swift package for iOS/macOS UI testing with screenshot capture and validation.

## Products

| Product | Type | Description |
|---------|------|-------------|
| **ScreenshotKit** | Library | Screenshot capture with structured naming |
| **UITestKit** | Library | Page Object protocols, XCUIElement extensions, Allure annotations |
| **extract-screenshots** | CLI | Extract/organize screenshots from xcresult (macOS only, terminal use) |

> **Note:** Only add `ScreenshotKit` and `UITestKit` to your UI test target. The `extract-screenshots` CLI uses `Foundation.Process` which is unavailable on iOS — do NOT add it as a target dependency. Run it from terminal only.

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

# Run tests and extract screenshots
./Scripts/run-tests-and-extract.sh -workspace App.xcworkspace -scheme App
```

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
- Allure integration (optional)

## Requirements

- iOS 15.0+ / macOS 13.0+
- Swift 6.2+
- Xcode 26+

Run `./Scripts/check-tools.sh` to verify.
