# TASK-260615-1jj8m2: add-sample-smoke-command

## Description
Add a sample smoke command that runs the standalone coordinator proof from the toolkit repo, starts the coordinator, launches sample peers, waits for completion, and writes artifacts under .temp.

## Scope
Add a local smoke entrypoint that starts the coordinator, runs fake peers, validates expected events and receipts, and stores artifacts in .temp.

## Acceptance Criteria
Smoke command runs without consumer product projects and without devices. It fails if any expected event, receipt, replay, payload, timestamp, or artifact is missing and writes event log plus summary under .temp.
