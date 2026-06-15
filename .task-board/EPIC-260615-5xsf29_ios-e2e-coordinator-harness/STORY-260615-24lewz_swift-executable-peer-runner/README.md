# STORY-260615-24lewz: swift-executable-peer-runner

## Description
Implement the macOS Swift executable facade that parses config, starts the WebSocket coordinator server, patches test environments, launches N XCUITest peers, supervises processes, and collects artifacts.

## Scope
Runner executable behavior: config loading, coordinator lifecycle, peer launch planning, xcodebuild supervision, environment injection, dry-run mode, and artifact collection.

## Acceptance Criteria
Runner dry-run validates config and prints launch plan. Real mode injects E2E env, starts coordinator, launches peers, supervises xcodebuild, and writes logs, event log, receipts, xcresults, screenshots, and summary.
