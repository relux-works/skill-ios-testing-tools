# TASK-260615-b5oyjr: implement-ios-e2e-runner-cli

## Description
Implement macOS Swift CLI that loads project config, starts the local coordinator, patches XCUITest environment, launches configured peers through xcodebuild test-without-building, supervises processes, and returns a session result.

## Scope
Implement the macOS Swift executable target and CLI argument parsing, session startup, config loading, environment injection, xcodebuild command construction, peer supervision, cleanup, and result propagation.

## Acceptance Criteria
CLI can run in dry-run mode without devices and prints the exact peer launch plan. Process execution is abstracted so tests can verify command construction, environment injection, failure propagation, and cleanup.
