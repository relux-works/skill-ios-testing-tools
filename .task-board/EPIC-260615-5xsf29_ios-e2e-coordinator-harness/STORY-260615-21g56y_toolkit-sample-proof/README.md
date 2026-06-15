# STORY-260615-21g56y: toolkit-sample-proof

## Description
Create a standalone sample inside skill-ios-testing-tools that proves the WebSocket E2E coordinator concept without Tap2Cash, Xcode UI tests, or physical devices.

## Scope
Standalone toolkit proof only: fake peers, sample config, smoke command, and local artifacts. The sample must run without Tap2Cash, Xcode UI tests, or physical devices.

## Acceptance Criteria
Sample runs locally from the toolkit repo, launches at least three fake peers, verifies broadcast except sender, delivery ack barriers, replay/history, JSON payloads, timestamp envelope, wait predicates, and artifact output before Tap2Cash integration begins.
